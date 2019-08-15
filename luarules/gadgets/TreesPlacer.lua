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
				if y > minTreeHeight and y < maxTreeHeight and math.random(1,getHeightDensity(y,invDensity)) == 1 and Spring.TestMoveOrder(UnitDefNames.vehassault.id, x, y, z) == true then
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





