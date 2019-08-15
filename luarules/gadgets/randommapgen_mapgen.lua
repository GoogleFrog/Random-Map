
function gadget:GetInfo()
	return {
		name	= "MapGen",
		desc	= "MapGENERATOR325550",
		author	= "Doo",
		date	= "July,2016",
		layer	= -math.huge + 4,
        enabled = false,
		}
end


--------------------------------------------------------------------------------
-- synced
--------------------------------------------------------------------------------
if gadgetHandler:IsSyncedCode() then

	local gdheight = Spring.GetGroundHeight
	local testBuild = Spring.TestBuildOrder
	local mapOptions = Spring.GetMapOptions
	local SetHeightMap = Spring.SetHeightMap
	local SetSmoothMesh = Spring.SetSmoothMesh
	local SetMetal = Spring.SetMetalAmount

	-- MAPDEPENDANT VARS
	local sizeX = Game.mapSizeX
	local sizeZ = Game.mapSizeZ
	local sqr = Game.squareSize
	local startingSize = 512
	while sizeX%(startingSize*2) == 0 and sizeZ%(startingSize*2) == 0 do -- get the highest startingSize possible
		startingSize = startingSize*2
	end

	-- PARAMS
	local height
	local roadlevelfactor
	local flattenRatio
	local heightGrouping
	local nbRoads
	local nbMountains
	local levelground
	local nbMetalSpots
	local symType
	local typemap
	local flatness -- goal standard derivation of height = sqrt(variance) (per 8x8 sqr)
	local variance
	local meanHeight
	local nCells
	local roadHeight
	local metalspotvalue
	local sizeFactor
	local nbGeos
	
	local rand = math.random
	local floor = math.floor
	local min = math.min
	local max = math.max
	local sqrt = math.sqrt
	local randseed = math.randomseed
	
	function gadget:Initialize()
		local randomSeed
		variance = 0
		meanHeight = 1
		nCells = 0
		if mapOptions() and mapOptions().seed and tonumber(mapOptions().seed) ~= 0 then
			randomSeed = tonumber(mapOptions().seed)
		else
			randomSeed = rand(1,10000)
		end
		randseed( randomSeed )
		Spring.Echo("Random Seed = "..tostring(randomSeed)..", Symtype = "..tostring((mapOptions() and mapOptions().symtype and tonumber(mapOptions().symtype)) or 0))
		
		local nbTeams = 0
		for i, team in pairs (Spring.GetTeamList()) do
			if team ~= Spring.GetGaiaTeamID() then
				nbTeams = nbTeams + 1
			end
		end
		if nbTeams < 2 then
			nbTeams = 2
		end
		
	-- PARAMS
		metalspotvalue = rand(128,255)
		flatness = rand(300,500)
		height = rand(256,1024)
		roadlevelfactor = rand(10,100)/10 -- higher means flatter roads
		flattenRatio = 1 -- rand(25,200)/100 -- lower means flatter final render
		heightGrouping = rand(10,64) -- higher means more plateaus, lower means smoother but more regular height differences
		heightGrouping = (heightGrouping)/flattenRatio
		sizeFactor = 1.15^(((sizeX / 512)^2)/(8*8) - 1)
		nbRoads = rand(1,7) * sizeFactor
		nbMountains = rand(1,4) * sizeFactor
		nbMetalSpots = (rand(40,70)/10) * sizeFactor -- = (4-7 * 2 per 8x8 square) * sqrt(nbteams)
		nbGeos = (rand(0,1)/10) * sizeFactor -- = (0-2 * 2 per 8x8 square) * sqrt(nbteams)
		symType = (mapOptions() and mapOptions().symtype and ((tonumber(mapOptions().symtype))~= 0) and tonumber(mapOptions().symtype)) or rand(1,5) --sprang: Always symmetric
		typemap = rand(1,4)
		nbSmooth = 5
		if typemap == 1 then
			Spring.SetGameRulesParam("typemap", "arctic")
			heightGrouping = floor(heightGrouping*0.3) + 1
			height = floor(height*1.5)
			flatness = flatness * 8
			nbRoads = floor(nbRoads*0.3)
			roadHeight = 0
			roadlevelfactor = nil
			nbMountains = floor(nbMountains*4)
			nbMetalSpots = (nbMetalSpots*1)
			levelground = 0
			nbSmooth = 2
			minroadsize = 8
			maxroadsize = 256
		elseif typemap == 2 then
			Spring.SetGameRulesParam("typemap", "desert")
			heightGrouping = rand(60,80)
			height = floor(height*1.0)
			flatness = flatness
			nbRoads = floor(nbRoads*0.7)
			roadHeight = 0
			roadlevelfactor = nil
			nbMountains = floor(nbMountains*0.6)
			nbMetalSpots = (nbMetalSpots*1.0)
			levelground = rand(-80,110)
			minroadsize = 64
			maxroadsize = 512
		elseif typemap == 3 then
			Spring.SetGameRulesParam("typemap", "moon")
			heightGrouping = floor(heightGrouping*0.1) + 1
			height = floor(height*0.6)
			flatness = flatness * 0.8
			nbRoads = floor(nbRoads*0)
			roadlevelfactor = roadlevelfactor/10
			roadHeight = height
			nbMountains = floor(nbMountains*1.5)
			nbMetalSpots = (nbMetalSpots*1.1)
			levelground = 300
			minroadsize = 64
			maxroadsize = 256
		elseif typemap == 4 then
			Spring.SetGameRulesParam("typemap", "temperate")
			heightGrouping = floor(heightGrouping*0.8) + 1
			height = floor(height*1)
			flatness = flatness * 3
			nbRoads = floor(nbRoads*1)
			roadHeight = -40
			roadlevelfactor = roadlevelfactor/5
			nbMountains = floor(nbMountains*1.3)
			nbMetalSpots = (nbMetalSpots*1)
			levelground = rand(-100,40)
			minroadsize = 8
			maxroadsize = 256
		end
		if symType == 6 then
			nbMetalSpots = nbMetalSpots * 2
		end
		
		Heightranges = height
		symTable = GenerateSymmetryTable() -- Generate a symmetry table (symTable.x[x] => x')
		local Cells,Size = GenerateCells(startingSize) -- generate the initial cell(s)
		roads = GenerateRoads(Size)	-- Generate a set of "roads"
		mountains = GenerateMountains(Size) -- Generate a set of "mountains"		
		
		while Size >= sqr*2^5 do -- use diamond square rendering for startingSize => squareSize * 8
			Cells,Size,Heightranges = SquareDiamond(Cells, Size, Heightranges)
			Spring.ClearWatchDogTimer()
		end
		
		Cells,Size = ApplySymmetry(Cells,Size, symTable) -- Reapply the symetry
		
		while Size >= sqr*2^3 do -- use diamond square rendering for startingSize => squareSize * 4
			Cells,Size,Heightranges = SquareDiamond(Cells, Size, Heightranges)
			Spring.ClearWatchDogTimer()
		end
		
		Cells,Size = GroupCellsByHeight(Cells,Size) -- Apply congruence to cells heights
		CreateSmoothMesh(Cells,Size)
		while Size >= sqr*2 do
			Cells,Size = SquareDiamondSmoothing(Cells, Size) -- Complete rendering to squareSize/2
			Spring.ClearWatchDogTimer()
		end
		
		while Size >= sqr*2 do -- failsafe to make sure final stage is squareSize/2
			Cells,Size = FinishCells(Cells,Size)
			Spring.ClearWatchDogTimer()
		end
		
		for i = 1,nbSmooth do -- smooth (mean of 8 closest cells), repeated 5 times
			Cells, Size = FinalSmoothing(Cells, Size)
			Spring.ClearWatchDogTimer()
		end

		Spring.SetHeightMapFunc(ApplyHeightMap, Cells) -- Apply the height map
		nbMetalSpots = floor(sqrt(nbTeams) * nbMetalSpots)
		metalspots = GenerateMetalSpots(nbMetalSpots)
		SetUpMetalSpots(metalspots)
		nbGeos = floor(sqrt(nbTeams) * nbGeos)
		Geos = GenerateGeoSpots(nbGeos)
		SetUpGeoSpots(Geos)
		
		Cells = nil
		metalspots = nil
		mountains = nil
		roads = nil
	end
	
	function CreateSmoothMesh(cells, size)
		Spring.SetSmoothMeshFunc(SmoothMeshFunc, cells, size)
	end
	
	SmoothMeshFunc = function(cells, size)
		for x = 0,sizeX, size do
			for z = 0, sizeZ, size do
				SetSmoothMesh(x, z, cells[x][z] * flattenRatio + levelground + 120)
			end
		end
	end
	
	
	function SetUpMetalSpots(metal)
		for x = 0,sizeX,sqr do
			for z = 0,sizeZ,sqr do
				if metal and metal[x] and metal[x][z] then
					local X, Z = floor(x/16), floor(z/16)
					SetMetal(X,Z, metalspotvalue)
				else
					local X, Z = floor(x/16), floor(z/16)
					SetMetal(X,Z, 0)		
				end
			end
		end
	end
	
	function SetUpGeoSpots(geos)
		for i, pos in pairs(geos) do
			Spring.CreateFeature("geovent", pos.x, gdheight(pos.x, pos.z), pos.z)
		end
	end
	
	function GenerateSymmetryTable()
		local symTable = {x = {}, z = {}}
		if symType == 1 then -- Central Symetry
			symTable = function(x,z,size)
				return {x = sizeX - x, z = sizeZ - z}
			end
		elseif symType == 2 then -- vertical symTable
			symTable = function(x,z,size)
				return {x = sizeX - x, z = z}
			end
		elseif symType == 3 then -- horizontal symTable
			symTable = function(x,z,size)
				return {x = x, z = sizeZ - z}
			end
		elseif symType == 4 then -- diagonal c1 symTable
			symTable = function(x,z,size)
				return {x = z, z = x}
			end
		elseif symType == 5 then -- diagonal c2 symTable
			symTable = function(x,z,size)
				return {x = sizeZ - z, z = sizeX - x}
			end
		elseif symType == 6 then
			symTable = function(x,z,size)
				return {x = x, z = z}
			end
		end
		return symTable
	end
	
	function CloseMetalSpot(x,z,metal)
		local radiussqr = 320^2
		local symdissqr = (symTable(x,z).x - x)^2 + (symTable(x,z).z - z)^2
		if symType == 6 then
			symdissqr = 321^2
		end
		if symdissqr < radiussqr then
			return true
		end
		for i = 1, #metal do
			local pos = metal[i]
			local addsqr =  (pos.x - x)^2 + (pos.z - z)^2
			if addsqr < radiussqr then
				return true
			end
		end
		return false
	end
		
	function GenerateMetalSpots(n)
		local metalSpotSize = 48
		local metal = {}
		local METAL = {}
		for i = 1,n*2,2 do
			local x = rand(metalSpotSize,sizeX-metalSpotSize)
			local z = rand(metalSpotSize,sizeZ-metalSpotSize)
			local metalSpotCloseBy = CloseMetalSpot(x,z,metal)
				--while (testBuild(UnitDefNames["armmoho"].id, x,gdheight(x,z),z, 1) == 0 and testBuild(UnitDefNames["armuwmme"].id, x,gdheight(x,z),z, 1) == 0) or metalSpotCloseBy == true do
                while metalSpotCloseBy == true do
					x = rand(metalSpotSize,sizeX-metalSpotSize)
					z = rand(metalSpotSize,sizeZ-metalSpotSize)
					metalSpotCloseBy = CloseMetalSpot(x,z,metal)
				end
			x = x - x%metalSpotSize
			z = z - z%metalSpotSize
			metal[i] = {x = x, z = z, size = metalSpotSize}
			metal[i+1] = {x = symTable(x,z).x, z = symTable(x,z).z, size = metalSpotSize}
		end
		for i = 1, #metal do
			local pos = metal[i]
			for v = -pos.size/2,pos.size/2 -1, sqr do
				METAL[pos.x + v] = METAL[pos.x + v] or {}
				for w = -pos.size/2,pos.size/2 -1, sqr do
					METAL[pos.x + v][pos.z + w] = true
				end
			end
		end
		return METAL
	end

	function CloseGeoSpot(x,z,geos)
		local radiussqr = 320^2
		local symdissqr = (symTable(x,z).x - x)^2 + (symTable(x,z).z - z)^2
		if symType == 6 then
			symdissqr = 321^2
		end
		if symdissqr < radiussqr then
			return true
		end
		for i = 1, #geos do
			local pos = geos[i]
			local addsqr =  (pos.x - x)^2 + (pos.z - z)^2
			if addsqr < radiussqr then
				return true
			end
		end
		return false
	end
	
	function GenerateGeoSpots(n)
		local geos = {}
		local GEOS = {}
		for i = 1,n*2,2 do
			local x = rand(0,sizeX)
			local z = rand(0,sizeZ)
			local geoSpotCloseBy = CloseMetalSpot(x,z,geos)
				--while (testBuild(UnitDefNames["armafus"].id, x,gdheight(x,z),z, 1) == 0 or testBuild(UnitDefNames["armuwadves"].id, x,gdheight(x,z),z, 1) == 0) or geoSpotCloseBy == true do
                while testBuild(UnitDefNames["energygeo"].id, x,gdheight(x,z),z, 1) == 0 or geoSpotCloseBy == true do
					x = rand(0,sizeX)
					z = rand(0,sizeZ)
					geoSpotCloseBy = CloseGeoSpot(x,z,geos)
				end
			x = x - x%16
			z = z - z%16
			geos[i] = {x = x, z = z}
			geos[i+1] = {x = symTable(x,z).x, z = symTable(x,z).z}
		end
		for i = 1, #geos do
			local pos = geos[i]
			GEOS[i] = pos
		end
		return GEOS
	end
			
	function ApplySymmetry(cells, size, symTable)
		if symType == 6 then
			return cells, size
		end
		local newroads, newmountains = {}, {}
		local newcells = {}
		for x = 0,sizeX,sqr do
			local cellsx = cells[x] ~= nil
			local roadx =  roads[x] ~= nil
			local mountainsx = mountains[x] ~= nil
			newroads[x] = newroads[x] or {}
			newmountains[x] = newmountains[x] or {}
			newcells[x] = newcells[x] or {}
			if mountainsx or roadx then
				for z = 0,sizeZ,sqr do
					if cells[x] then
						newcells[symTable(x,z,size).x] = newcells[symTable(x,z,size).x] or {}	
						newcells[x][z] = cells[x][z]
						newcells[symTable(x,z,size).x][symTable(x,z,size).z] = cells[x][z]
					end
					if roadx then
						newroads[symTable(x,z,size).x] = newroads[symTable(x,z,size).x] or {}
						newroads[x][z] = roads[x][z]
						newroads[symTable(x,z,size).x][symTable(x,z,size).z] = roads[x][z]	
					end
					if mountainsx then
						newmountains[symTable(x,z,size).x] = newmountains[symTable(x,z,size).x] or {}
						newmountains[x][z] = mountains[x][z]
						newmountains[symTable(x,z,size).x][symTable(x,z,size).z] = mountains[x][z]	
					end
				end
			else
				for z = 0,sizeZ,size do
					if cellsx then
						newcells[symTable(x,z,size).x] = newcells[symTable(x,z,size).x] or {}	
						newcells[x][z] = cells[x][z]
						newcells[symTable(x,z,size).x][symTable(x,z,size).z] = cells[x][z]
					end
				end
			end
			Spring.ClearWatchDogTimer()
		end
		roads = newroads
		mountains = newmountains
		return newcells, size
	end
	
	function GroupCellsByHeight(cells, size)
		for x = 0,sizeX,size do
			for z = 0,sizeZ,size do
				if cells[x][z] then
					if not (roads and roads[x] and roads[x][z]) then
						cells[x][z] = cells[x][z] - (cells[x][z]%heightGrouping)
					end
				end
			end
			Spring.ClearWatchDogTimer()
		end
		return cells, size
	end
	
	function GenerateRoads(size)
		local ROADS = {}
		local road = {}
		local directions = {
		{x = 1, z = 1},
		{x = 1, z = 0},
		{x = 1, z = -1},
		{x = 0, z = 1},
		{x = 0, z = -1},
		{x = -1, z = 1},
		{x = -1, z = 0},
		{x = -1, z = -1},
		}
		if nbRoads < 1 then
			return ROADS
		end
		for i = 1, nbRoads do
			rSize = 32
			local curX = rand(sqr,sizeX-sqr)
			local curZ = rand(sqr,sizeZ-sqr)
			curX = curX - curX%sqr
			curZ = curZ - curZ%sqr
			local positions = {[1] = {x = curX, z = curZ, ["size"] = rSize}}
			local lastdir
			for j = 2,256 do
				rSize = rSize * 2^(rand(-3,3))
				if rSize < minroadsize then
					rSize = minroadsize
				elseif rSize >maxroadsize then
					rSize = maxroadsize
				end
				local attempt = 1
				local moveAmnt = (min(128,rSize))
				local dir = rand(1,8)
				local nextX = curX + directions[dir].x*moveAmnt	
				local nextZ = curZ + directions[dir].z*moveAmnt		
				roadcellsaround = (ROADS[nextX - moveAmnt] and ROADS[nextX - moveAmnt][nextZ] and 1 or 0) + (ROADS[nextX + moveAmnt] and ROADS[nextX + moveAmnt][nextZ] and 1 or 0) + (ROADS[nextX] and ROADS[nextX][nextZ - moveAmnt] and 1 or 0) + (ROADS[nextX] and ROADS[nextX][nextZ + moveAmnt] and 1 or 0)
				while attempt <= 10 and roadcellsaround > 3 do
					dir = rand(1,8)
					nextX = curX + directions[dir].x*moveAmnt	
					nextZ = curZ + directions[dir].z*moveAmnt		
					roadcellsaround = (ROADS[nextX - moveAmnt] and ROADS[nextX - moveAmnt][nextZ] and 1 or 0) + (ROADS[nextX + moveAmnt] and ROADS[nextX + moveAmnt][nextZ] and 1 or 0) + (ROADS[nextX] and ROADS[nextX][nextZ - moveAmnt] and 1 or 0) + (ROADS[nextX] and ROADS[nextX][nextZ + moveAmnt] and 1 or 0)
					attempt = attempt + 1
				end

				lastdir = dir
				curX = nextX - curX%sqr
				curZ = nextZ - curZ%sqr
				for v = 0,rSize -1, sqr do
					ROADS[curX + v] = ROADS[curX + v] or {}
					for w = 0,rSize -1, sqr do
						ROADS[curX + v][curZ + w] = true
					end
				end
				if curX <= 0 or curX >= sizeX or curZ <= 0 or curZ >= sizeZ then
					break
				end
			end
			Spring.ClearWatchDogTimer()
		end	
		return ROADS
	end
	
	function GenerateMountains(size)
		local MOUNTAINS = {}
		if nbMountains == 0 then
			return MOUNTAINS
		end
		for i = 1,nbMountains do
			local x = rand(0,sizeX)
			local z = rand(0,sizeZ)
			local size = rand (256,1024)
			x = x - x%sqr
			z = z - z%sqr
			size = size - size%sqr
			for v = -size, size-1, sqr do
				for w = -size, size-1, sqr do
					MOUNTAINS[x+v] = MOUNTAINS[x+v] or {}
					if v^2 + w^2 < size^2 then
						MOUNTAINS[x+v][z+w] = true
					end
				end
			end
			Spring.ClearWatchDogTimer()
		end
		return MOUNTAINS
	end
	
	function ApplyHeightMap(cells)
		for x = 0,sizeX,sqr do
			for z = 0,sizeZ,sqr do
				local height = cells[x][z] * flattenRatio + levelground -- avoid -2 < height < 2 because it looks weird...
				if height >= -1 and height <= 3 then
					height = 3
				end
				if height <= -150 then
					height = -150
				end
				SetHeightMap(x,z, height )
			end
			Spring.ClearWatchDogTimer()
		end
	end
	
	function GenerateCells(size)
		local cells = {}
		nCells = 0
		for x = 0,sizeX,size do
			cells[x] = cells[x] or {}
			for z = 0,sizeZ,size do
				cells[x][z] = rand(0,size/8)
				meanHeight = size/16
				variance = (variance*nCells + (cells[x][z] - meanHeight)^2)/(nCells+1)
				nCells = nCells + 1
			end
		end
		return cells,size
	end
	
	function FinishCells(cells, size)
		local newsize = size/2
		for x = 0,sizeX,size do
			for z = 0,sizeZ,size do
				for k =0,size-1,newsize do
					cells[x+k] = cells[x+k] or {}
					for v = 0,size-1,newsize do
						cells[x+k][z+v] = cells[x][z]
					end
				end
			end
			Spring.ClearWatchDogTimer()
		end
		return cells, newsize
	end
	
	function PickRandom(range, variance)
		local ratio = 1
		local mini =0
		local maxi =0
		stdDerivation = sqrt(variance)
		if stdDerivation > flatness then
			ratio = flatness/stdDerivation
		end
		if typemap == 1 then
			mini =-range*ratio
			maxi =range*ratio
		elseif typemap == 2 then
			mini =-range*ratio
			maxi =range*ratio
		elseif typemap == 3 then
			mini =-range*ratio
			maxi =0
		elseif typemap == 4 then
			mini =-range*ratio
			maxi =range*ratio
		end
		return (rand(mini, maxi))
	end
	
	function SquareDiamond(cells, size, heightranges)
		local newsize = size / 2
		for x = 0,sizeX,size do --SquareCenter
			local roadx = roads[x+newsize] ~= nil
			cells[x+newsize] = cells[x+newsize] or {}
			for z = 0,sizeZ,size do
				if x + newsize <= sizeX and z+newsize <= sizeZ then
					local heightChangeRange = (mountains and mountains[x+newsize] and mountains[x+newsize][z+newsize] and heightranges*1.5) or heightranges/4
					if roadx and roads[x+newsize][z+newsize] then
						cells[x+newsize][z+newsize] = mean4diagroad(cells,x+newsize, z+newsize, newsize)
					else
						cells[x+newsize][z+newsize] = mean4diag(cells,x+newsize, z+newsize, newsize) + PickRandom(heightChangeRange, variance)
					end
				end
			end
			Spring.ClearWatchDogTimer()
		end
		variance = 0
		nCells = 0
		for x = 0,sizeX,newsize do -- Edges
			local roadx = roads[x] ~= nil
			cells[x] = cells[x] or {}
			for z = 0,sizeZ,newsize do
				local heightChangeRange = (mountains and mountains[x] and mountains[x][z] and heightranges*1.5) or heightranges/4
				if not (cells[x][z]) then
					if roadx and roads[x][z] then
						cells[x][z] = mean4strroad(cells,x, z, newsize)
					else
						cells[x][z] = mean4str(cells,x, z, newsize) + PickRandom(heightChangeRange, variance)						
					end
				end
				variance = (variance*nCells + (cells[x][z] - meanHeight)^2) / (nCells+1)
				nCells = nCells + 1
			end
			Spring.ClearWatchDogTimer()
		end
		heightranges = heightranges/2
		return cells, newsize, heightranges
	end
	
	function SquareDiamondSmoothing(cells, size)
		local newsize = size / 2
		for x = 0,sizeX,size do --SquareCenter
			local roadx = roads[x+newsize] ~= nil
			cells[x+newsize] = cells[x+newsize] or {}
			for z = 0,sizeZ,size do
				if x + newsize <= sizeX and z+newsize <= sizeZ then
					if roadx and roads[x+newsize][z+newsize] then
					cells[x+newsize][z+newsize] = mean4diagroad(cells,x+newsize, z+newsize, newsize)	
					else
					cells[x+newsize][z+newsize] = mean4diag(cells,x+newsize, z+newsize, newsize)
					end
				end
			end
			Spring.ClearWatchDogTimer()
		end
		for x = 0,sizeX,newsize do -- Edges
			local roadx = roads[x] ~= nil
			cells[x] = cells[x] or {}
			for z = 0,sizeZ,newsize do
				if not (cells[x][z]) then
					if roadx and roads[x][z] then
						cells[x][z] = mean4strroad(cells,x, z, newsize)
					else
						cells[x][z] = mean4str(cells,x, z, newsize)
					end
				end
			end
			Spring.ClearWatchDogTimer()
		end
		return cells, newsize
	end
	
	function FinalSmoothing(cells, size)
		for x = 0,sizeX,size do
			for z = 0,sizeZ,size do
				cells[x][z] = mean8(cells,x,z,size)
				if typemap == 3 then
					levelground = max(-cells[x][z] + 20,levelground)
				end
			end
			Spring.ClearWatchDogTimer()
		end
		return cells, size
	end
	
	function mean4str(tab, x, z, size)
		local sum = 0
		local num = 0
		if x > 0 then
			sum = sum + tab[x-size][z]	 
			num = num + 1
		end
		if x < sizeX then
			sum = sum + tab[x+size][z]	 
			num = num + 1
		end
		if z > 0 then
			sum = sum + tab[x][z-size]	 
			num = num + 1
		end
		if z < sizeZ then
			sum = sum + tab[x][z+size]	 
			num = num + 1
		end
		return sum/num
	end
	
	function mean4diag(tab, x, z, size)
		local sum = 0
		local num = 0
		if x > 0 then
			if z > 0 then
				sum = sum + tab[x-size][z-size]	 
				num = num + 1
			end
			if z < sizeZ then
				sum = sum + tab[x-size][z+size]	 
				num = num + 1
			end
		end
		if x < sizeX then
			if z > 0 then
				sum = sum + tab[x+size][z-size]	 
				num = num + 1
			end
			if z < sizeZ then
				sum = sum + tab[x+size][z+size]	 
				num = num + 1
			end
		end
		return sum/num
	end
	
						
	function mean4strroad(tab, x, z, size)
		local sum = 0
		local num = 0
		if x > 0 then
			local factor = ((roads[x-size] and roads[x-size][z]) and (roadlevelfactor or 1) or (rand(0,25)/100))
			sum = sum + tab[x-size][z] * factor
			num = num + factor
		end
		if x < sizeX then
			local factor = ((roads[x+size] and roads[x+size][z]) and (roadlevelfactor or 1) or (rand(0,25)/100))
			sum = sum + tab[x+size][z] * factor
			num = num + factor
		end
		if z > 0 then
			local factor = ((roads[x][z-size]) and (roadlevelfactor or 1) or (rand(0,25)/100))
			sum = sum + tab[x][z-size] * factor
			num = num + factor
		end
		if z < sizeZ then
			local factor = ((roads[x][z+size]) and (roadlevelfactor or 1) or (rand(0,25)/100))
			sum = sum + tab[x][z+size] * factor
			num = num + factor
		end
		sum = sum + roadHeight*(roadlevelfactor or 0)
		num = num + (roadlevelfactor or 0)
		return sum/num
	end
	
	function mean4diagroad(tab, x, z, size)
		local sum = 0
		local num = 0
		if x > 0 then
			if z > 0 then
				local factor = ((roads[x-size] and roads[x-size][z-size]) and (roadlevelfactor or 1) or (rand(0,25)/100))
				sum = sum + tab[x-size][z-size] * factor
				num = num + factor
			end
			if z < sizeZ then
				local factor = ((roads[x-size] and roads[x-size][z+size]) and (roadlevelfactor or 1) or (rand(0,25)/100))
				sum = sum + tab[x-size][z+size] * factor
				num = num + factor
			end
		end
		if x < sizeX then
			if z > 0 then
				local factor = ((roads[x+size] and roads[x+size][z-size]) and (roadlevelfactor or 1) or (rand(0,25)/100))
				sum = sum + tab[x+size][z-size] * factor
				num = num + factor
			end
			if z < sizeZ then
				local factor = ((roads[x+size] and roads[x+size][z+size]) and (roadlevelfactor or 1) or (rand(0,25)/100))
				sum = sum + tab[x+size][z+size] * factor
				num = num + factor
			end
		end
		sum = sum + roadHeight*(roadlevelfactor or 0)
		num = num + (roadlevelfactor or 0)
		return sum/num
	end
	
	function mean8(tab, x, z, size)
		local sum = tab[x][z]
		local num = 1
		if x > 0 then
			sum = sum + tab[x-size][z]	 
			num = num + 1
			if z > 0 then
				sum = sum + tab[x-size][z-size]	 
				num = num + 1
			end
			if z < sizeZ then
				sum = sum + tab[x-size][z+size]	 
				num = num + 1
			end
		end
		if x < sizeX then
			sum = sum + tab[x+size][z]	 
			num = num + 1
			if z > 0 then
				sum = sum + tab[x+size][z-size]	 
				num = num + 1
			end
			if z < sizeZ then
				sum = sum + tab[x+size][z+size]	 
				num = num + 1
			end
		end
		if z < sizeZ then
			sum = sum + tab[x][z+size]	 
			num = num + 1
		end
		if z > 0 then
			sum = sum + tab[x][z-size]	 
			num = num + 1
		end
		return (sum/num)
	end
	
end

