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

local MAX_NORMAL = 0.91
local VEH_NORMAL = 0.892
local BOT_NORMAL = 0.585

if not (gadgetHandler:IsSyncedCode()) then  --Sync
	return
end

local MAP_X = Game.mapSizeX
local MAP_Z = Game.mapSizeZ

local minTreeHeight = 130
local maxTreeHeight = 260
local minDistance = 64
local density = 0.8

local floor = math.floor
local ceil = math.ceil

local DENSITY_SAMPLE_RADIUS = 550

local lowTreeMap = {1, 1, 3, 5}
local highTreeMap = {2, 4, 6, 6}

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
	local dist = DENSITY_SAMPLE_RADIUS*(math.random()^2)
	local angle = math.random()*2*math.pi
	x = math.max(0, math.min(MAP_X, x + dist*math.cos(angle)))
	z = math.max(0, math.min(MAP_Z, z + dist*math.sin(angle)))
	local mx = floor(x/densitySize)*densitySize
	local mz = floor(z/densitySize)*densitySize
	return (densityMap[mx] and densityMap[mx][mz]) or 1
end

local function GetTreeSlopeChance(x, z)
	local normal      = select(2, Spring.GetGroundNormal(x, z, true))
	local height      = Spring.GetGroundHeight(x, z)
	if (normal > MAX_NORMAL) then
		return 1
	end
	return 0
end

local function GetTree(treeList, height)
	if height < minTreeHeight + 0.45*(maxTreeHeight - minTreeHeight) then
		return treeList[lowTreeMap[1 + math.floor(#lowTreeMap*math.random())]]
	elseif height > minTreeHeight + 0.55*(maxTreeHeight - minTreeHeight) then
		return treeList[highTreeMap[1 + math.floor(#highTreeMap*math.random())]]
	end
	return treeList[1 + math.floor(6*math.random())]
end

function gadget:Initialize()
	if Spring.GetGameFrame() > 0 then
		return false
	end
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
		Spring.Utilities.TableEcho(replacementTrees, "replacementTrees")
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
	for x = 0, Game.mapSizeX - 1, minDistance do
		for z = 0, Game.mapSizeZ - 1, minDistance do
			local px = x + math.random()*minDistance
			local pz = z + math.random()*minDistance
			local py = Spring.GetGroundHeight(px, pz)
			if py > minTreeHeight and py < maxTreeHeight and
					math.random() < getHeightDensity(py, invDensity) and
					math.random() < GetTreeSlopeChance(px, pz) and
					math.random() < GetCellTreeDensity(x, z) then
				local rx, rz = floor(px/16), floor(pz/16)
				if not (avoidMex[rx] and avoidMex[rx][rz]) then
					Spring.CreateFeature(GetTree(replacementTrees, py), px, py, pz, math.random(0, 360)*math.pi*2/360)
				end
			end
		end
	end
end

function gadget:Shutdown()
	local features = Spring.GetAllFeatures()
	for i = 1, #features do
		local featureID = features[i]
		Spring.DestroyFeature(featureID)
	end
end
