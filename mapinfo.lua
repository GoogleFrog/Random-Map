--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- mapinfo.lua
--

local mapinfo = {
	name        = "Random Plateaus",
	shortname   = "rplat",
	description = "A sometimes craggy, sometimes plateauy random map, now with igloos (10x10)",
	author      = "GoogleFrog",
	version     = "v0.84",
	modtype     = 3, --// 1=primary, 0=hidden, 3=map

	maphardness     = 140,
	notDeformable   = false,
	gravity         = 130,
	tidalStrength   = 18,
	maxMetal        = 1.20,
	extractorRadius = 110,
	voidWater       = false,
	autoShowMetal   = true,

	smf = {
		minheight = -105,
		maxheight = 280,
		smtFileName0 = "RandomBaseMap10.smt",
	},

	sound = {
		preset = "default",
		passfilter = {
			gainlf = 1.0,
			gainhf = 1.0,
		},
		reverb = {
		},
	},

	resources = {
		splatDetailTex = "Rock.png",
		splatDetailNormalDiffuseAlpha = 1,
		splatDetailNormalTex = {
			"grass.tga", -- Grass
			"rock.tga", -- Rocky grass
			"sand.tga", -- shallowSand
			"volcano.tga", -- Depth Sand
			alpha = true,
		},
	},
	splats = {
		TexScales = { 0.00471, 0.00097, 0.0013, 0.0027 },
		TexMults = { 0.5, 0.31, 0.5, 0.65 },
	},

	atmosphere = {
		minWind      = 5.0,
		maxWind      = 25.0,

		fogStart     = 0,
		fogEnd       = 500,
		fogColor     = {0.7, 0.7, 0.8},

		sunColor     = {1.0, 1.0, 1.0},
		skyColor     = {0.1, 0.15, 0.7},
		skyDir       = {0.0, 0.0, -1.0},
		skyBox       = "",

		cloudDensity = 0.5,
		cloudColor   = {1.0, 1.0, 1.0},
	},

	grass = {
		bladeWaveScale = 1.0,
		bladeWidth  = 0.32,
		bladeHeight = 4.0,
		bladeAngle  = 1.57,
		bladeColor  = {0.59, 0.81, 0.57}, --// does nothing when `grassBladeTex` is set
	},

	lighting = {
		--// dynsun
		sunStartAngle = 0.0,
		sunOrbitTime  = 1440.0,
		sunDir        = {0.35, 1.0, 0.3, 1e9},

		--// unit & ground lighting
		["groundDiffuseColor"]= {0.35, 0.42, 0.41, 1},
		["groundAmbientColor"]= {0.42, 0.45, 0.365, 1},
		["groundSpecularColor"]= {0.1, 0.1, 0.1, 1},
		groundShadowDensity = 0.4,
		unitAmbientColor    = {0.55, 0.55, 0.45},
		unitDiffuseColor    = {0.85, 0.85, 0.85},
		unitSpecularColor   = {0.85, 0.85, 0.85},
		unitShadowDensity   = 0.4,
		
		specularExponent    = 3.0,
	},
	
	water = {
		damage =  0,

		["surfaceColor"]= {0.55778897, 0.73869348, 0.57788944, 1},
		["fresnelMin"]= 0.07,
		["blurExponent"]= 0.51999998,
		["reflectionDistortion"]= 0,
		["specularColor"]= {0.37185928, 0.42211056, 0.55778897, 1},
		["fresnelPower"]= 2.63999987,
		["specularPower"]= 10.3999996,
		["perlinStartFreq"]= 9.59999943,
		["absorb"]= {0, 0, 0, 0.59798998},
		["fresnelMax"]= 0.34999999,
		["diffuseColor"]= {0.77386934, 0.68844223, 0.65326631, 1},
		["perlinAmplitude"]= 1.43999994,
		["perlinLacunarity"]= 2.3599999,
		["specularFactor"]= 0.25999999,
		["minColor"]= {0.36683416, 0.30653265, 0.53266335, 1},
		["planeColor"]= {0.40201005, 0.40703517, 0.6231156, 1},
		["surfaceAlpha"]= 0.16,
		["blurBase"]= 0,
		["diffuseFactor"]= 0.42999998,
		["repeatX"]= 7.79999971,
		["ambientFactor"]= 0.74000001,
		["repeatY"]= 9.80000019,
		["baseColor"]= {0, 0, 0, 1},

		shoreWaves = true,
		forceRendering = false,
		normalTexture = "waterbump.png",
	},

	teams = {
		[0] = {startPos = {x = 936, z = 5210}},
		[1] = {startPos = {x = 7280, z = 2981}},
		[2] = {startPos = {x = 2787, z = 7564}},
		[3] = {startPos = {x = 5409, z = 611}},
		[4] = {startPos = {x = (2460), z = 6202}},
		[5] = {startPos = {x = (5706), z = 1988}},
		[6] = {startPos = {x = (62) , z = 1638}},
		[7] = {startPos = {x = (8120), z = 6493}},
	},

	terrainTypes = {
		[0] = {
			name = "Default",
			hardness = 1.0,
			receiveTracks = true,
			moveSpeeds = {
				tank  = 1.0,
				kbot  = 1.0,
				hover = 0.9,
				ship  = 0.9,
			},
		},
	},
}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Helper

local function lowerkeys(ta)
	local fix = {}
	for i,v in pairs(ta) do
		if (type(i) == "string") then
			if (i ~= i:lower()) then
				fix[#fix+1] = i
			end
		end
		if (type(v) == "table") then
			lowerkeys(v)
		end
	end
	
	for i=1,#fix do
		local idx = fix[i]
		ta[idx:lower()] = ta[idx]
		ta[idx] = nil
	end
end

lowerkeys(mapinfo)

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Map Options

if (Spring) then
	local function tmerge(t1, t2)
		for i,v in pairs(t2) do
			if (type(v) == "table") then
				t1[i] = t1[i] or {}
				tmerge(t1[i], v)
			else
				t1[i] = v
			end
		end
	end

	-- make code safe in unitsync
	if (not Spring.GetMapOptions) then
		Spring.GetMapOptions = function() return {} end
	end
	function tobool(val)
		local t = type(val)
		if (t == 'nil') then
			return false
		elseif (t == 'boolean') then
			return val
		elseif (t == 'number') then
			return (val ~= 0)
		elseif (t == 'string') then
			return ((val ~= '0') and (val ~= 'false'))
		end
		return false
	end

	getfenv()["mapinfo"] = mapinfo
		local files = VFS.DirList("mapconfig/mapinfo/", "*.lua")
		table.sort(files)
		for i=1,#files do
			local newcfg = VFS.Include(files[i])
			if newcfg then
				lowerkeys(newcfg)
				tmerge(mapinfo, newcfg)
			end
		end
	getfenv()["mapinfo"] = nil
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

return mapinfo

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
