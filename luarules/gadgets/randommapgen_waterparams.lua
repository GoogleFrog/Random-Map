local engineVersion = 100 -- just filled this in here incorrectly but old engines arent used anyway
if Engine and Engine.version then
	local function Split(s, separator)
		local results = {}
		for part in s:gmatch("[^"..separator.."]+") do
			results[#results + 1] = part
		end
		return results
	end
	engineVersion = Split(Engine.version, '-')
	if engineVersion[2] ~= nil and engineVersion[3] ~= nil then
		engineVersion = tonumber(string.gsub(engineVersion[1], '%.', '')..engineVersion[2])
	else
		engineVersion = tonumber(Engine.version)
	end
elseif Game and Game.version then
	engineVersion = tonumber(Game.version)
end

-- fixed: https://springrts.com/mantis/view.php?id=5864
if not ((engineVersion < 1000 and engineVersion <= 105) or engineVersion >= 10401803) or (Game and Game.version and tonumber(Game.version) == 103) then
	return
end

function gadget:GetInfo()
	return {
		name	= "WaterParams",
		desc	= "Sets water Params",
		author	= "Doo",
		date	= "July,2016",
		layer	= 11,
        enabled = (select(1, Spring.GetGameFrame()) <= 0),
	}
end


--------------------------------------------------------------------------------
-- synced
--------------------------------------------------------------------------------
if gadgetHandler:IsSyncedCode() then
	function gadget:Initialize()
		local typemap = Spring.GetGameRulesParam("typemap")
		local r = math.random
		local params = {}
		local tidal = 18
		if typemap == "arctic" then
			 params = {
				   absorb = { 0.002,  0.0015,  0.001},
				   baseColor = { 0.4,  0.7,  0.8},
				   minColor = { 0.1,  0.2,  0.3},
				   -- surfaceColor = { r,  g,  b},
				   -- diffuseColor = { r,  g,  b},
				   -- specularColor = { r,  g,  b},
				   planeColor = { 0.1,  0.1,  0.3},
			 }
		 	tidal = 9
		elseif typemap == "temperate" then
			 params = {
				   absorb = { 0.004,  0.003,  0.002},
				   baseColor = { 0.4,  0.7,  0.8},
				   minColor = { 0.1,  0.2,  0.3},
				   -- surfaceColor = { r,  g,  b},
				   -- diffuseColor = { r,  g,  b},
				   -- specularColor = { r,  g,  b},
				   planeColor = { 0.1,  0.1,  0.3},
			 }
		 	tidal = 18
		elseif typemap == "temperate2" then
			 params = {
				   absorb = { 0.004,  0.003,  0.002},
				   baseColor = { 0.4,  0.7,  0.8},
				   minColor = { 0.1,  0.2,  0.3},
				   -- surfaceColor = { r,  g,  b},
				   -- diffuseColor = { r,  g,  b},
				   -- specularColor = { r,  g,  b},
				   planeColor = { 0.1,  0.1,  0.3},
			 }
		 	tidal = 18
		elseif typemap == "desert" then
			 params = {
				   -- absorb = { 0.004,  0.003,  0.002},
				   -- baseColor = { 0.4,  0.7,  0.8},
				   -- minColor = { 0.1,  0.2,  0.3},
				   -- surfaceColor = { r,  g,  b},
				   -- diffuseColor = { r,  g,  b},
				   -- specularColor = { r,  g,  b},
				   -- planeColor = { 0.1,  0.1,  0.3},
			 }
		 	tidal = 13
		else -- moon
			 params = {
				   absorb = { 0,  0,  0},
				   baseColor = { 0,  0,  0},
				   minColor = { 0,  0,  0},
				   surfaceColor = { 0,  0,  0},
				   -- diffuseColor = { r,  g,  b},
				   -- specularColor = { r,  g,  b},
				   planeColor = { 0,  0,  0},
			 }
		 	tidal = 0
		end
		Spring.SetWaterParams(params)
		Spring.SetTidal(tidal)
	end
end

