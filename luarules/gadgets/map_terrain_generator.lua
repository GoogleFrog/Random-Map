--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
if not gadgetHandler:IsSyncedCode() then
	return
end
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
	return {
		name      = "Map Terrain Generator",
		desc      = "Generates random terrain",
		author    = "GoogleFrog",
		date      = "14 August 2019",
		license   = "GNU GPL, v2 or later",
		layer     = 0,
		enabled   = true  --  loaded by default?
	}
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local MAP_X = Game.mapSizeX
local MAP_Z = Game.mapSizeZ
local MID_X = MAP_X/2
local MID_Z = MAP_Z/2
local SQUARE_SIZE = Game.squareSize

local spSetHeightMap = Spring.SetHeightMap

local sqrt = math.sqrt
local pi   = math.pi
local cos  = math.cos
local sin  = math.sin
local abs  = math.abs
local log  = math.log

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Heightmap manipulation

local function FlattenMap(height)
	for x = 0, MAP_X, SQUARE_SIZE do
		for z = 0, MAP_Z, SQUARE_SIZE do
			spSetHeightMap(x, z, height)
		end
		Spring.ClearWatchDogTimer()
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Debug

local function PointEcho(point, text)
	Spring.MarkerAddPoint(point[1], 0, point[2], text or "")
end

local function LineEcho(p1, p2)
	if p2 then
		Spring.MarkerAddLine(p1[1], 0, p1[2], p2[1], 0, p2[2], true)
	else
		Spring.MarkerAddLine(p1[1][1], 0, p1[1][2], p1[2][1], 0, p1[2][2], true)
		Spring.MarkerAddLine(p1[2][1] + 20, 0, p1[2][2], p1[2][1] - 20, 0, p1[2][2], true)
		Spring.MarkerAddLine(p1[2][1], 0, p1[2][2] + 20, p1[2][1], 0, p1[2][2] - 20, true)
	end
end

local function CellEcho(cells)
	for i = 1, #cells do
		local thisCell = cells[i]
		PointEcho(thisCell.site, "Cell: " .. i .. ", edges: " .. #thisCell.edges)
		for k = 1, #thisCell.edges do
			LineEcho(thisCell.edges[k])
			--PointEcho(Add(thisCell.edges[k][1], {i*16, 0}), i)
		end
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Vector

local function DistSq(p1, p2)
	return (p1[1] - p2[1])^2 + (p1[2] - p2[2])^2
end

local function Dist(p1, p2)
	return sqrt(DistSq(p1, p2))
end

local function Mult(b, v)
	return {b*v[1], b*v[2]}
end

local function Add(v1, v2)
	return {v1[1] + v2[1], v1[2] + v2[2]}
end

local function Subtract(v1, v2)
	return {v1[1] - v2[1], v1[2] - v2[2]}
end

local function AbsVal(x, y, z)
	if z then
		return sqrt(x*x + y*y + z*z)
	elseif y then
		return sqrt(x*x + y*y)
	elseif x[3] then
		return sqrt(x[1]*x[1] + x[2]*x[2] + x[3]*x[3])
	else
		return sqrt(x[1]*x[1] + x[2]*x[2])
	end
end

local function Unit(v)
	local mag = AbsVal(v)
	if mag > 0 then
		return {v[1]/mag, v[2]/mag}
	else
		return v
	end
end

local function Norm(b, v)
	local mag = AbsVal(v)
	if mag > 0 then
		return {b*v[1]/mag, b*v[2]/mag}
	else
		return v
	end
end

local function RotateLeft(v)
	return {-v[2], v[1]}
end

local function Angle(x,z)
	if not z then
		x, z = x[1], x[2]
	end
	if x == 0 and z == 0 then
		return 0
	end
	local mult = 1/AbsVal(x, z)
	x, z = x*mult, z*mult
	if z > 0 then
		return math.acos(x)
	elseif z < 0 then
		return 2*math.pi - math.acos(x)
	elseif x < 0 then
		return math.pi
	end
	-- x < 0
	return 0
end

local function Dot(v1, v2)
	if v1[3] then
		return v1[1]*v2[1] + v1[2]*v2[2] + v1[3]*v2[3]
	else
		return v1[1]*v2[1] + v1[2]*v2[2]
	end
end

function Cross(v1, v2)
	return {v1[2]*v2[3] - v1[3]*v2[2], v1[3]*v2[1] - v1[1]*v2[3], v1[1]*v2[2] - v1[2]*v2[1]}
end

-- Projection of v1 onto v2
local function Project(v1, v2)
	local uV2 = Unit(v2)
	return Mult(Dot(v1, uV2), uV2)
end

-- The normal of v1 onto v2. Returns such that v1 = normal + projection
local function Normal(v1, v2)
	local projection = Project(v1, v2)
	return Subtract(v1, projection), projection
end

local function GetMidpoint(p1, p2)
	local v = Subtract(p1, p2)
	return Add(p2, Mult(0.5, v))
end

local function IsPositiveIntersect(lineInt, lineMid, lineDir)
	return Dot(Subtract(lineInt, lineMid), lineDir) > 0
end

local function DistanceToLine(point, line)
	local startToPos = Subtract(point, line[1])
	local startToEnd = Subtract(line[2], line[1])
	local normal, projection = Normal(startToPos, Subtract(line[2], line[1]))
	local projFactor = Dot(projection, startToEnd)
	if projFactor < 0 then
		return Dist(line[1], point)
	end
	if projFactor > 1 then
		return Dist(line[2], point)
	end
	return AbsVal(Subtract(startToPos, normal))
end

local function GetRandomDir()
	local angle = math.random()*2*pi
	return {cos(angle), sin(angle)}
end

local function GetRandomSign()
	return (math.floor(math.random()*2))*2 - 1
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Point manipulation

local function GetClosestPoint(point, nearPoints)
	if not nearPoints[1] then
		return false
	end
	local closeIndex = 1
	local closeDistSq = DistSq(point, nearPoints[1])
	for i = 2, #nearPoints do
		local thisDistSq = DistSq(point, nearPoints[i])
		if thisDistSq < closeDistSq then
			closeIndex = i
			closeDistSq = thisDistSq
		end
	end
	
	return closeIndex, closeDistSq
end

local function GetPointCell(point, cells)
	if not cells[1] then
		return false
	end
	local closeIndex = 1
	local closeDistSq = DistSq(point, cells[1].site)
	for i = 2, #cells do
		local thisDistSq = DistSq(point, cells[i].site)
		if thisDistSq < closeDistSq then
			closeIndex = i
			closeDistSq = thisDistSq
		end
	end
	
	return closeIndex, closeDistSq
end

local function GetClosestPointDistSq(point, nearPoints)
	local _, distSq =  GetClosestPoint(point, nearPoints)
	return distSq or 999999999999999999
end

local function GetRandomPoint(avoidDist, avoidPoints, maxAttempts)
	local point = {math.random()*MAP_X, math.random()*MAP_Z}
	if not avoidDist then
		return point
	end
	local avoidDistSq = avoidDist^2
	
	local attempts = 1
	while GetClosestPointDistSq(point, avoidPoints) < avoidDistSq do
		point = {math.random()*MAP_X, math.random()*MAP_Z}
		attempts = attempts + 1
		if attempts > maxAttempts then
			break
		end
	end
	
	return point
end

local function ApplyRotSymmetry(point)
	return {MAP_X - point[1], MAP_Z - point[2]}
end

local function GetBoundedLineIntersection(line1, line2)
	local x1, y1, x2, y2 = line1[1][1], line1[1][2], line1[2][1], line1[2][2]
	local x3, y3, x4, y4 = line2[1][1], line2[1][2], line2[2][1], line2[2][2]
	
	local denominator = ((x1 - x2)*(y3 - y4) - (y1 - y2)*(x3 - x4))
	if denominator == 0 then
		return false
	end
	local first = ((x1 - x3)*(y3 - y4) - (y1 - y3)*(x3 - x4))/denominator
	local second = -1*((x1 - x2)*(y1 - y3) - (y1 - y2)*(x1 - x3))/denominator
	
	if first < 0 or first > 1 or (second < 0 or second > 1) then
		return false
	end
	
	local px = x1 + first*(x2 - x1)
	local py = y1 + first*(y2 - y1)
	
	return {px, py}
end

local function InMapBounds(point)
	return not (point[1] < 0 or point[2] < 0 or point[1] > MAP_X or point[2] > MAP_Z)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Voronoi

local function GetBoundedLine(pos, dir, bounder)
	local line = {Add(pos, Mult(50*MAP_X, dir)), Add(pos, Mult(-50*MAP_X, dir))}
	return line
end

local OUTER_POINTS = {
	{ -4*MAP_X,  -4*MAP_Z},
	{ -4*MAP_X,   5*MAP_Z},
	{  5*MAP_X,  -4*MAP_Z},
	{  5*MAP_X,   5*MAP_Z},
}

local MAP_BORDER = {
	{{-10*MAP_X,     0}, {10*MAP_X,     0}},
	{{-10*MAP_X, MAP_Z}, {10*MAP_X, MAP_Z}},
	{{    0, -10*MAP_Z}, {    0, 10*MAP_Z}},
	{{MAP_X, -10*MAP_Z}, {MAP_X, 10*MAP_Z}},
}

local function InitVoronoi()
	
	local cells = {}
	for i = 1, #OUTER_POINTS do
		local newCell = {
			site = OUTER_POINTS[i],
			edges = {},
		}
		local cellCorners = {
			{-4.5*MAP_X, -4.5*MAP_Z},
			{ 4.5*MAP_X, -4.5*MAP_Z},
			{ 4.5*MAP_X,  4.5*MAP_Z},
			{-4.5*MAP_X,  4.5*MAP_Z},
		}
		
		local sx, sz = newCell.site[1], newCell.site[2]
		for j = 1, #cellCorners do
			newCell.edges[#newCell.edges + 1] = {Add(newCell.site, cellCorners[j]), Add(newCell.site, cellCorners[(j%4) + 1])}
		end
		cells[#cells + 1] = newCell
	end
	
	local offset = {10*MAP_X, 10*MAP_Z}
	
	return cells
end

local function GenerateVoronoi(pointNum, minDist)
	local points = {}
	for i = 1, pointNum do
		points[#points + 1] = GetRandomPoint(minDist, points, 50)
		points[#points + 1] = ApplyRotSymmetry(points[#points])
	end
	
	local cells = InitVoronoi()
	
	for i = 1, #points do
		local newCell = {
			site = points[i],
			edges = {},
		}
		for j = 1, #cells do
			local otherCell = cells[j]
			local pos = GetMidpoint(newCell.site, otherCell.site)
			local dir = RotateLeft(Unit(Subtract(newCell.site, otherCell.site)))
			local line = GetBoundedLine(pos, dir, OUTER_BOUNDS)
			
			local intersections = false
			for k = #otherCell.edges, 1, -1 do
				local otherEdge = otherCell.edges[k]
				local int = GetBoundedLineIntersection(line, otherEdge)
				if int then
					if GetBoundedLineIntersection(line, {otherEdge[1], otherCell.site}) then
						otherCell.edges[k] = {int, otherCell.edges[k][2]}
					else
						otherCell.edges[k] = {otherCell.edges[k][1], int}
					end
					intersections = intersections or {}
					intersections[#intersections + 1] = int
				else
					if GetBoundedLineIntersection(line, {otherEdge[1], otherCell.site}) then
						otherCell.edges[k] = otherCell.edges[#otherCell.edges]
						otherCell.edges[#otherCell.edges] = nil
					end
				end
			end
			if intersections then
				newCell.edges[#newCell.edges + 1] = intersections
				otherCell.edges[#otherCell.edges + 1] = intersections
			end
		end
		cells[#cells + 1] = newCell
	end
	
	for i = 1, #MAP_BORDER do
		local borderLine = MAP_BORDER[i]
		for j = #cells, 1, -1 do
			local thisCell = cells[j]
			if not InMapBounds(thisCell.site) then
				cells[j] = cells[#cells]
				cells[#cells] = nil
			else
				local intersections = false
				for k = #thisCell.edges, 1, -1 do
					local thisEdge = thisCell.edges[k]
					local int = GetBoundedLineIntersection(borderLine, thisEdge)
					if int then
						if GetBoundedLineIntersection(borderLine, {thisEdge[1], thisCell.site}) then
							thisCell.edges[k] = {int, thisCell.edges[k][2]}
						else
							thisCell.edges[k] = {thisCell.edges[k][1], int}
						end
						intersections = intersections or {}
						intersections[#intersections + 1] = int
					else
						if GetBoundedLineIntersection(borderLine, {thisEdge[1], thisCell.site}) then
							thisCell.edges[k] = thisCell.edges[#thisCell.edges]
							thisCell.edges[#thisCell.edges] = nil
						end
					end
				end
				if intersections then
					thisCell.edges[#thisCell.edges + 1] = intersections
				end
			end
		end
	end
	
	return cells
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Base terrain generation

local function GetWave(translational, params)
	local spread = params.spread or ((params.spreadMin or 1) + ((params.spreadMax or 1) - (params.spreadMin or 1))*math.random())
	local scale  = params.scale  or ((params.scaleMin  or 1) + ((params.scaleMax  or 1) - (params.scaleMin  or 1))*math.random())
	local period = params.period or ((params.periodMin or 1) + ((params.periodMax or 1) - (params.periodMin or 1))*math.random())
	local offset = params.offset or ((params.offsetMin or 1) + ((params.offsetMax or 1) - (params.offsetMin or 1))*math.random())
	local growth = params.growth or ((params.growthMin or 1) + ((params.growthMax or 1) - (params.growthMin or 1))*math.random())

	scale = scale*GetRandomSign()
	growth = growth*GetRandomSign()
	
	--Spring.Echo("scale", scale, "period", period, "offset", offset, "growth", growth)
	-- Growth is increase in amplitude per (unmodified) peak-to-peak distance.
	growth = growth/period
	
	-- Period is peak-to-peak distance.
	period = period/(2*pi)
	
	local dir, wavePeriod, zeroAngle
	
	if translational then
		dir =  translational and GetRandomDir()
		wavePeriod = translational and math.ceil(params.wavePeriod or ((params.wavePeriodMin or 1) + ((params.wavePeriodMax or 1) - (params.wavePeriodMin or 1))*math.random()))
		wavePeriod = wavePeriod/(2*pi)
	else
		zeroAngle = (not translational) and math.random()*2*pi
		local waveRotations = (not translational) and (params.waveRotations or ((params.waveRotationsMin or 1) + ((params.waveRotationsMax or 1) - (params.waveRotationsMin or 1))*math.random()))
		waveRotations = math.ceil(waveRotations/2)*2 -- Must be even for twofold rotational symmetry
		wavePeriod = 1/waveRotations
		
		spread = spread/(period*(2*pi))
	end
	
	local function GetValue(x, z)
		x = x - MID_X
		z = z - MID_Z
		
		local normal, tangent
		if translational then
			normal  = dir[1]*x + dir[2]*z
			tangent = dir[1]*z - dir[2]*x
			
			-- Implement translate spread
			normal = abs(normal - sin(tangent/wavePeriod)*spread)
		else
			normal  = sqrt(x^2 + z^2)
			tangent = Angle(x,z) + zeroAngle
			
			-- Implement scale spread
			normal = abs(normal*(1 + sin(tangent/wavePeriod)*spread))
		end
		
		return -1*(cos((normal/period)) - 1)*(normal*growth + scale) + offset
	end
	
	return GetValue
end

local function GetTranslationalWave(params)
	return GetWave(true, params)
end

local function GetRotationalWave(params)
	return GetWave(false, params)
end

local function TerraformByFunc(func)
	local function DoTerra()
		for x = 0, MAP_X, SQUARE_SIZE do
			for z = 0, MAP_Z, SQUARE_SIZE do
				spSetHeightMap(x, z, func(x, z))
			end
			Spring.ClearWatchDogTimer()
		end
	end
	
	Spring.SetHeightMapFunc(DoTerra)
end

local function TerraformByFuncAndVoronoi(func, cells)
	local function DoTerra()
		local point = {0, 0}
		for x = 0, MAP_X, SQUARE_SIZE do
			for z = 0, MAP_Z, SQUARE_SIZE do
				point[1], point[2] = x, z
				local cellIndex = GetPointCell(point, cells)
				spSetHeightMap(x, z, func(cells[cellIndex].site[1], cells[cellIndex].site[2]))
			end
			Spring.ClearWatchDogTimer()
		end
	end

	Spring.SetHeightMapFunc(DoTerra)
end

local function GetTerrainWaveFunction()
	local multParams = {
		scaleMin = 0.3,
		scaleMax = 0.8,
		periodMin = 2000,
		periodMax = 5000,
		spreadMin = 200,
		spreadMax = 1200,
		offsetMin = -0.2,
		offsetMax = 0.2,
		growthMin = 0.15,
		growthMax = 0.2,
		wavePeriodMin = 1000,
		wavePeriodMax = 2600,
		waveRotationsMin = 1,
		waveRotationsMax = 8,
	}
	
	local params = {
		scaleMin = 30,
		scaleMax = 60,
		periodMin = 1800,
		periodMax = 3000,
		spreadMin = 20,
		spreadMax = 120,
		offsetMin = 30,
		offsetMax = 90,
		growthMin = 5,
		growthMax = 20,
		wavePeriodMin = 800,
		wavePeriodMax = 1700,
		waveRotationsMin = 1,
		waveRotationsMax = 8,
	}
	
	local rotParams = {
		scaleMin = 30,
		scaleMax = 60,
		periodMin = 1800,
		periodMax = 4000,
		spreadMin = 60,
		spreadMax = 300,
		offsetMin = 30,
		offsetMax = 90,
		growthMin = 5,
		growthMax = 20,
		wavePeriodMin = 800,
		wavePeriodMax = 1700,
		waveRotationsMin = 1,
		waveRotationsMax = 8,
	}

	local bigMultParams = {
		scaleMin = 0.7,
		scaleMax = 1,
		periodMin = 18000,
		periodMax = 45000,
		spreadMin = 2000,
		spreadMax = 8000,
		offsetMin = 0.1,
		offsetMax = 0.4,
		growthMin = 0.02,
		growthMax = 0.2,
		wavePeriodMin = 5000,
		wavePeriodMax = 12000,
		waveRotationsMin = 1,
		waveRotationsMax = 8,
	}
	
	local rotMult = GetRotationalWave(multParams)
	local transMult = GetTranslationalWave(multParams)

	local rot = GetRotationalWave(rotParams)
	local trans = GetTranslationalWave(params)
	params.periodMin = params.periodMin*1.6
	params.periodMax = params.periodMax*1.6
	
	local trans2 = GetTranslationalWave(params)
	local transMult2 = GetTranslationalWave(multParams)
	params.periodMin = params.periodMin*1.6
	params.periodMax = params.periodMax*1.6
	
	local trans3 = GetTranslationalWave(params)
	local rotMult3 = GetRotationalWave(multParams)
	params.periodMin = params.periodMin*1.6
	params.periodMax = params.periodMax*1.6
	
	local bigMult = GetTranslationalWave(bigMultParams)
	
	local function GetValue(x, z)
		--return bigMult(x,z)*100
		return 1.6*(rot(x,z)*transMult(x,z) + trans(x,z)*rotMult(x,z) + bigMult(x,z)*(trans2(x,z)*transMult2(x,z) + trans3(x,z)*rotMult3(x,z)) + 70)
	end
	
	return GetValue
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Callins

function gadget:Initialize()
	Spring.SetGameRulesParam("typemap", "temperate")
	Spring.MarkerAddPoint(MID_X, 0, MID_Z, "Mid")
	
	--if Spring.GetGameFrame() < 1 then
	--	Spring.SetHeightMapFunc(FlattenMap, 10)
	--end
	
	local waveFunc = GetTerrainWaveFunction()
	--TerraformByFunc(waveFunc)
	
	local cells = GenerateVoronoi(18, 220)
	--CellEcho(cells)
	
	TerraformByFuncAndVoronoi(waveFunc, cells)
	
	--Spring.Utilities.TableEcho(GetBoundedLineIntersection({{1,1}, {5, 3}}, {{3, 4}, {2, -3}}), "Intersect")
	--Spring.Echo("DistanceToLineAlternateAlternate({0, 4}, {{0, 0}, {4, 4}})", DistanceToLineAlternateAlternate({0, 4}, {{0, 0}, {4, 4}}))
	--Spring.Utilities.TableEcho(Project({0, 4}, {4,4}), "Project({0, 4}, {4,4})")
end
