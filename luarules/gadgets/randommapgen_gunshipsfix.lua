
function gadget:GetInfo()
	return {
		name    = "AirFix",
		desc    = "AirFix",
		author  = "Doo",
		date    = "July,2016",
		layer   = 11,
		enabled = false,
	}
end

--------------------------------------------------------------------------------
-- synced
--------------------------------------------------------------------------------
if gadgetHandler:IsSyncedCode() then
	local gunships = {}
	for unitDefID, uDef in pairs(UnitDefs) do
		if uDef.canFly == true and uDef.hoverAttack == true then
			gunships[unitDefID] = true
		end
	end
	
	function gadget:UnitCreated(unitID, unitDefID)
		if gunships[unitDefID] == true then
			Spring.MoveCtrl.SetGunshipMoveTypeData(unitID, "useSmoothMesh", false)
		end
	end
	
	function gadget:Initialize()
		for i, unitID in pairs (Spring.GetAllUnits()) do
			gadget:UnitCreated(unitID, Spring.GetUnitDefID(unitID))
		end
	end
end

