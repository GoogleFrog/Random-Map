function gadget:GetInfo()
   return {
      name         = "Trees Spawner",
      desc         = "Places trees",
      author       = "Doo",
      date         = "26/04/2016",
      license      = "GPL 2.0 or later", -- should be compatible with Spring
      layer        = 10,
        enabled = (select(1, Spring.GetGameFrame()) <= 0),
   }
end

local MAX_NORMAL = 0.96
local VEH_NORMAL = 0.892
local BOT_NORMAL = 0.585

if (gadgetHandler:IsSyncedCode()) then  --Sync
	local minTreeHeight = 10
	local maxTreeHeight = 600
	local minDistance = 16
	local density = 1/24
	local getHeightDensity = function(y, invdensity) 
		local dy = (y - 10)/(600-10)
		local mod = -(math.min(1,dy+1))
		return (1-mod) * invdensity
	end
	
	local function GetTreeSlopeChance(x, z)
		local normal      = select(2, Spring.GetGroundNormal(x, z, true))
		local height      = Spring.GetGroundHeight(x, z)
		if (normal > MAX_NORMAL) then
			return 1
		elseif (normal < VEH_NORMAL) then
			return 0
		end
		
		return (normal - VEH_NORMAL)/( MAX_NORMAL - VEH_NORMAL)
	end
	
	
	function gadget:Initialize()
		-- get all replacement trees
		local replacementTrees = {}
		local count = 0
		local typemap = Spring.GetGameRulesParam("typemap")
		for featureDefID, featureDef in pairs(FeatureDefs) do
			if string.find(featureDef.name, "lowpoly_tree_") then
				if typemap == "arctic" then
					if string.find(featureDef.name, "lowpoly_tree_snowy") then
						count = count + 1
						replacementTrees[count] = featureDefID
					end
				elseif typemap == "desert" then
					if string.find(featureDef.name, "burnt") then
						count = count + 1
						replacementTrees[count] = featureDefID
					end
				elseif typemap == "moon" then
					return -- no trees on the moon ! 
				elseif typemap == "temperate" then
					if not (string.find(featureDef.name, "lowpoly_tree_snowy") or string.find(featureDef.name, "burnt")) then
						count = count + 1
						replacementTrees[count] = featureDefID
					end
				end
			end
		end
		if not replacementTrees[1] then
			for featureDefID, featureDef in pairs(FeatureDefs) do
				if string.find(featureDef.name, "tree") then
					count = count + 1
					replacementTrees[count] = featureDefID
				end 
			end
		end
		
		-- Get Random positions
		local ctTrees = 0
		local trees = {}
		local invDensity = 1/density
		for x = 0,Game.mapSizeX, minDistance do
			for z = 0,Game.mapSizeZ, minDistance do
				local y = Spring.GetGroundHeight(x,z)
				if y > minTreeHeight and y < maxTreeHeight and math.random(1,getHeightDensity(y,invDensity)) == 1 and math.random() < GetTreeSlopeChance(x, z) then
					ctTrees = ctTrees + 1
					trees[ctTrees] = {x = x, y = y, z = z}
				end
			end
		end
		
		for tree, pos in pairs(trees) do
			Spring.CreateFeature(replacementTrees[math.random(1,count)],(pos.x),(pos.y),(pos.z), math.random(0,360)*math.pi*2/360)
		end
	end
end
