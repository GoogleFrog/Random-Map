--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- mapinfo.lua
--

local mapinfo = {
	name        = "RandomMapGen12x12",
	shortname   = "RMG",
	description = "A random Map generator (12x12)",
	author      = "Doo",
	version     = "1.6.1 zk-compatible",
	--mutator   = "deployment";
	--mapfile   = "", --// location of smf/sm3 file (optional)
	modtype     = 3, --// 1=primary, 0=hidden, 3=map
	depend      = {"Map Helper v1"},
	replace     = {},

	--startpic   = "", --// deprecated
	--StartMusic = "", --// deprecated

	maphardness     = 100,
	notDeformable   = false,
	gravity         = 130,
	tidalStrength   = 18,
	maxMetal        = 1.20,
	extractorRadius = 110,
	voidWater       = false,
	autoShowMetal   = true,


	smf = {
		minheight = (-105),
		maxheight = (280),
		smtFileName1 = "RandomMapGen12x12.smf",
		--smtFileName.. = "",
		--smtFileNameN = "",
	},

	sound = {
		--// Sets the _reverb_ preset (= echo parameters),
		--// passfilter (the direct sound) is unchanged.
		--//
		--// To get a list of all possible presets check:
		--//   https://github.com/spring/spring/blob/master/rts/System/Sound/OpenAL/EFXPresets.cpp
		--//
		--// Hint:
		--// You can change the preset at runtime via:
		--//   /tset UseEFX [1|0]
		--//   /tset snd_eaxpreset preset_name   (may change to a real cmd in the future)
		--//   /tset snd_filter %gainlf %gainhf  (may    "   "  "  "    "  "   "    "   )
		preset = "default",

		passfilter = {
			--// Note, you likely want to set these
			--// tags due to the fact that they are
			--// _not_ set by `preset`!
			--// So if you want to create a muffled
			--// sound you need to use them.
			gainlf = 1.0,
			gainhf = 1.0,
		},

		reverb = {
			--// Normally you just want use the `preset` tag
			--// but you can use handtweak a preset if wanted
			--// with the following tags.
			--// To know their function & ranges check the
			--// official OpenAL1.1 SDK document.
			
			--density
			--diffusion
			--gain
			--gainhf
			--gainlf
			--decaytime
			--decayhflimit
			--decayhfratio
			--decaylfratio
			--reflectionsgain
			--reflectionsdelay
			--reflectionspan
			--latereverbgain
			--latereverbdelay
			--latereverbpan
			--echotime
			--echodepth
			--modtime
			--moddepth
			--airabsorptiongainhf
			--hfreference
			--lfreference
			--roomrollofffactor
		},
	},

   resources = {
	-- skyReflectModTex = "lavareflect.bmp",
	-- lightEmissionTex = "lolemit.png",
	-- specularTex = "lolspec.png",
	splatDistrTex = "splatrep.png",
	splatDetailTex = "Rock.png",
    splatDetailNormalDiffuseAlpha = 1,
    splatDetailNormalTex = {
         "Grass.png", -- Grass
         "Rock.png", -- Rocky grass
         "DepthSand.png", -- shallowSand
         "DepthSand.png", -- Depth Sand
          alpha = true,
   },
   },
   splats = {
      texScales = {0.006, 0.02, 0.012, 0.012},
      texMults = {0.5, 0.3, 0.35, 0},
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
		sunDir        = {0.0, 1.0, 2.0, 1e9},

		--// unit & ground lighting
		groundAmbientColor  = {0.5, 0.5, 0.5},
		groundDiffuseColor  = {0.5, 0.5, 0.5},
		groundSpecularColor = {0.1, 0.1, 0.1},
		groundShadowDensity = 0.8,
		unitAmbientColor    = {0.4, 0.4, 0.4},
		unitDiffuseColor    = {0.7, 0.7, 0.7},
		unitSpecularColor   = {0.7, 0.7, 0.7},
		unitShadowDensity   = 0.8,
		
		specularExponent    = 100.0,
	},
	
  water = {
      damage =  0,

      repeatX = 0.0,
      repeatY = 0.0,

      absorb    = {0.004, 0.003, 0.002},
      baseColor = {0.4, 0.7, 0.8},
      minColor  = {0.1, 0.2, 0.3},

      ambientFactor  = 0.0,

      planeColor = {0.1, 0.1, 0.3},

      surfaceColor  = {0.4, 0.7, 0.8},

      fresnelMin   = 0.01,
      fresnelMax   = 0.02,
      fresnelPower = 0.015,

      reflectionDistortion = 0.1,

      blurBase      = 0,
      blurExponent = 0.1,

      perlinStartFreq  =  10,
      perlinLacunarity = 5,
      perlinAmplitude  =  1,
      windSpeed = 1, --// does nothing yet

      shoreWaves = true,	
      forceRendering = false,
      normalTexture = "waterbump.png",
	},

teams = { 	[0] = {startPos = {x = 936, z = 5210}},
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

	custom = {
		fog = {
			color    = {0.26, 0.30, 0.41},
			height   = "80%", --// allows either absolue sizes or in percent of map's MaxHeight
			fogatten = 0.003,
		},
		precipitation = {
			density   = 30000,
			size      = 1.5,
			speed     = 50,
			windscale = 1.2,
			texture   = 'LuaGaia/effects/snowflake.png',
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
