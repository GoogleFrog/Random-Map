local startBoxes = {}

local function GetStartboxName(midX, midZ)
	if (midX < 0.33) then
		if (midZ < 0.33) then
			return "North-West", "NW"
		elseif (midZ > 0.66) then
			return "South-West", "SW"
		else
			return "West", "W"
		end
	elseif (midX > 0.66) then
		if (midZ < 0.33) then
			return "North-East", "NE"
		elseif (midZ > 0.66) then
			return "South-East", "SE"
		else
			return "East", "E"
		end
	else
		if (midZ < 0.33) then
			return "North", "N"
		elseif (midZ > 0.66) then
			return "South", "S"
		else
			return "Center", "Center"
		end
	end
end

if not GG.mapgen_startBoxes then
	local box = {
		startpoints = {
			{
				227.909378,
				1284.64685,
			},
		},
		nameShort = "NW",
		boxes = {
			{
				{
					227.909378,
					1284.64685,
				},
			},
		},
		nameLong = "North-West",
	}
	return {[0] = box, [1] = box}
end

local boxNum = 0
for i = 1, #GG.mapgen_startBoxes do
	local points = GG.mapgen_startBoxes[i]
	local coords = {}
	local aveX = 0
	local aveZ = 0
	for j = 1, #points do
		aveX = aveX + points[j][1]
		aveZ = aveZ + points[j][2]
		coords[#coords + 1] = {points[j][1], points[j][2]}
	end
	
	aveX, aveZ = aveX/#coords, aveZ/#coords
	local nameLong, nameShort = GetStartboxName(aveX/Game.mapSizeX, aveZ/Game.mapSizeZ)
	
	startBoxes[boxNum] = {
		boxes = {
			coords
		},
		startpoints = {
			{aveX, aveZ},
		},
		nameLong = nameLong, 
		nameShort = nameShort,
	}
	boxNum = boxNum + 1
end

return startBoxes
