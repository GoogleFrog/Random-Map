function gadget:GetInfo()
   return {
      name         = "Trees Spawner",
      desc         = "Places trees",
      author       = "Doo",
      date         = "26/04/2016",
      license      = "GPL 2.0 or later", -- should be compatible with Spring
      layer        = 10,
      enabled      = true,
   }
end

local MAX_NORMAL = 0.965
local VEH_NORMAL = 0.892
local BOT_NORMAL = 0.585

if not (gadgetHandler:IsSyncedCode()) then  --Sync
	return
end

local minTreeHeight = 10
local maxTreeHeight = 600
local minDistance = 40
local density = 0.25

local floor = math.floor
local ceil = math.ceil

local getHeightDensity = function(y, invdensity) 
	local dy = (y - 10)/(900 - 10)
	local mod = -(math.min(1, dy+1))
	return (1 - mod) * invdensity
end

local function GetCellTreeDensity(x, z)
	local densityMap = GG.mapgen_treeDensityMap
	local densitySize = GG.mapgen_treeDensitySize
	if not densityMap then
		return 1
	end
	local mx = floor(x/densitySize)*densitySize + densitySize/2
	local mz = floor(z/densitySize)*densitySize + densitySize/2
	return (densityMap[mx] and densityMap[mx][mz]) or 1
end

local function GetTreeSlopeChance(x, z)
	local normal      = select(2, Spring.GetGroundNormal(x, z, true))
	local height      = Spring.GetGroundHeight(x, z)
	if (normal > MAX_NORMAL) then
		return 1
	elseif (normal < VEH_NORMAL) then
		return 0
	end
	--local slopeProp = 0.1*(normal - VEH_NORMAL)/( MAX_NORMAL - VEH_NORMAL)
	return 0
end


function gadget:Initialize()
	-- get all replacement trees
	local replacementTrees = {}
	local typeCount = 0
	local typemap = Spring.GetGameRulesParam("typemap")
	for featureDefID, featureDef in pairs(FeatureDefs) do
		if string.find(featureDef.name, "lowpoly_tree_") then
			if typemap == "arctic" then
				if string.find(featureDef.name, "lowpoly_tree_snowy") then
					typeCount = typeCount + 1
					replacementTrees[typeCount] = featureDefID
				end
			elseif typemap == "desert" then
				if string.find(featureDef.name, "burnt") then
					typeCount = typeCount + 1
					replacementTrees[typeCount] = featureDefID
				end
			elseif typemap == "moon" then
				return -- no trees on the moon ! 
			elseif typemap == "temperate" then
				if not (string.find(featureDef.name, "lowpoly_tree_snowy") or string.find(featureDef.name, "burnt")) then
					typeCount = typeCount + 1
					replacementTrees[typeCount] = featureDefID
				end
			end
		end
	end
	if not replacementTrees[1] then
		for featureDefID, featureDef in pairs(FeatureDefs) do
			if string.find(featureDef.name, "tree") then
				typeCount = typeCount + 1
				replacementTrees[typeCount] = featureDefID
			end 
		end
	end
	
	if typeCount == 0 then
		return
	end
	
	local mexSpots = GG.metalSpots or {}
	local avoidMex = {}
	for i = 1, #mexSpots do
		local sx, sz = floor(mexSpots[i].x/16), floor(mexSpots[i].z/16)
		for x = sx - 2, sx + 2 do
			avoidMex[x] = avoidMex[x] or {}
			for z = sz - 2, sz + 2 do
				avoidMex[x][z] = true
			end
		end
	end
	
	-- Get Random positions
	local invDensity = 1/density
	for x = 0, Game.mapSizeX, minDistance do
		for z = 0, Game.mapSizeZ, minDistance do
			local px = x + math.random()*minDistance - minDistance/2
			local pz = z + math.random()*minDistance - minDistance/2
			local py = Spring.GetGroundHeight(px, pz)
			if py > minTreeHeight and py < maxTreeHeight and
					math.random(1, getHeightDensity(py, invDensity)) == 1 and
					math.random() < GetTreeSlopeChance(px, pz) and
					math.random() < GetCellTreeDensity(px, pz) then
				
				local rx, rz = floor(px/16), floor(pz/16)
				if not (avoidMex[rx] and avoidMex[rx][rz]) then
					Spring.CreateFeature(replacementTrees[math.random(1, typeCount)], px, py, pz, math.random(0, 360)*math.pi*2/360)
				end
			end
		end
	end
end


function gadget:Shutdown()
	local features = Spring.GetAllFeatures()
	for i=1, #features do
		local featureID = features[i]
		Spring.DestroyFeature(featureID)
	end
end
