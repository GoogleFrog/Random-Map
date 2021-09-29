--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
if (gadgetHandler:IsSyncedCode()) then
	return
end
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
	return {
		name      = "Unified Texturing",
		desc      = "Applies basic textures on maps based on slopemap",
		author    = "Google Frog (edited for randommapgen purposes by Doo)",
		date      = "25 June 2012, edited 2018", --24 August 2013
		license   = "GNU GPL, v2 or later",
		layer     = 10,
		enabled   = true, --  loaded by default?
	}
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local MAP_X = Game.mapSizeX
local MAP_Z = Game.mapSizeZ
local MAP_FAC_X = 2/MAP_X
local MAP_FAC_Z = 2/MAP_X

local SQUARE_SIZE = 1024
local SQUARES_X = MAP_X/SQUARE_SIZE
local SQUARES_Z = MAP_Z/SQUARE_SIZE

local UHM_WIDTH = 64
local UHM_HEIGHT = 64

local UHM_X = UHM_WIDTH/MAP_X
local UHM_Z = UHM_HEIGHT/MAP_Z

local BLOCK_SIZE  = 1
local DRAW_OFFSET = 2 * BLOCK_SIZE/MAP_Z - 1

local VEH_NORMAL      = 0.892
local BOT_NORMAL_PLUS = 0.85
local BOT_NORMAL      = 0.585
local SHALLOW_HEIGHT  = -22

local USE_SHADING_TEXTURE = (Spring.GetConfigInt("AdvMapShading") == 1)

local spSetMapSquareTexture = Spring.SetMapSquareTexture
local spGetMapSquareTexture = Spring.GetMapSquareTexture
local spGetMyTeamID         = Spring.GetMyTeamID
local spGetGroundHeight     = Spring.GetGroundHeight
local spGetGroundOrigHeight = Spring.GetGroundOrigHeight
local SpGetMetalAmount      = Spring.GetMetalAmount
local SpTestMoveOrder       = Spring.TestMoveOrder
local SpTestBuildOrder      = Spring.TestBuildOrder

local glTexture         = gl.Texture
local glColor           = gl.Color
local glCreateTexture   = gl.CreateTexture
local glTexRect         = gl.TexRect
local glRect            = gl.Rect
local glDeleteTexture   = gl.DeleteTexture
local glRenderToTexture = gl.RenderToTexture
local glCreateShader    = gl.CreateShader
local glUseShader       = gl.UseShader
local glGetUniformLocation   = gl.GetUniformLocation
local glUniform              = gl.Uniform

local GL_RGBA = 0x1908

local GL_RGBA16F = 0x881A
local GL_RGBA32F = 0x8814

local BLACK_TEX = 1
local SPIDER_TEX = 5
local BOT_TEX = 5
local VEH_TEX = 20
local VEH_SAMPLE_RANGE = 1.5
local VEH_HEIGHT_MAX = 360
local VEH_HEIGHT_MIN = -50

local floor  = math.floor
local random = math.random

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local initialized, mapfullyprocessed = false, false

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local coroutine = coroutine
local Sleep     = coroutine.yield
local activeCoroutine

local function StartScript(fn)
	local co = coroutine.create(fn)
	activeCoroutine = co
end

local function UpdateCoroutines()
	if activeCoroutine then
		if coroutine.status(activeCoroutine) ~= "dead" then
			assert(coroutine.resume(activeCoroutine))
		else
			activeCoroutine = nil
		end
	end
end

local RATE_LIMIT = 12000

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function DrawTextureOnSquare(x, z, size, sx, sz, xsize, zsize)
	local x1 = 2*x/SQUARE_SIZE - 1
	local z1 = 2*z/SQUARE_SIZE - 1
	local x2 = 2*(x+size)/SQUARE_SIZE - 1
	local z2 = 2*(z+size)/SQUARE_SIZE - 1
	glTexRect(x1, z1, x2, z2, sx, sz, sx+xsize, sz+zsize)
end

local function DrawTexBlock(x, z)
	glTexRect(x*MAP_FAC_X - 1, z*MAP_FAC_Z - 1, x*MAP_FAC_X + DRAW_OFFSET, z*MAP_FAC_Z + DRAW_OFFSET)
end

local function DrawColorBlock(x, z)
	glRect(x*MAP_FAC_X -1, z*MAP_FAC_Z - 1, x*MAP_FAC_X + DRAW_OFFSET, z*MAP_FAC_Z + DRAW_OFFSET)
end

local function drawCopySquare()
	glTexRect(-1, 1, 1, -1)
end

local function LowerHalfRotateSymmetry()
	glTexRect(-1, -1, 1, 0, 0, 0, 1, 0.5)
	glTexRect(1, 1, -1, 0, 0, 0, 1, 0.5)
end

local function drawRectOnTex(x1, z1, x2, z2, sx1, sz1, sx2, sz2)
	glTexRect(x1, z1, x2, z2, sx1, sz1, sx2, sz2)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function RateCheck(loopCount, texture, color)
	if loopCount > RATE_LIMIT then
		loopCount = 0
		Sleep()
		if texture then
			glTexture(texture)
		elseif color then
			glColor(color)
		end
	end
	return loopCount + 1
end

local function SetMapTexture(texturePool, mapTexX, mapTexZ, topTexX, topTexZ, topTexAlpha, splatTexX, splatTexZ, splatTexCol, mapHeight)
	local DrawStart = Spring.GetTimer()
	local usedsplat
	local usedgrass
	local usedminimap

	local minHeight =  Spring.GetGameRulesParam("ground_min_override")
	local maxHeight = Spring.GetGameRulesParam("ground_max_override")

	local topFullTex = gl.CreateTexture(MAP_X/BLOCK_SIZE, MAP_Z/BLOCK_SIZE,
		{
			border = false,
			min_filter = GL.LINEAR,
			mag_filter = GL.LINEAR,
			wrap_s = GL.CLAMP_TO_EDGE,
			wrap_t = GL.CLAMP_TO_EDGE,
			fbo = true,
		}
	)
	if not topFullTex then
		return
	end
	
	Spring.Echo("Generated blank fulltex")
	local topSplattex = USE_SHADING_TEXTURE and gl.CreateTexture(MAP_X/BLOCK_SIZE, MAP_Z/BLOCK_SIZE,
		{
			format = GL_RGBA32F,
			border = false,
			min_filter = GL.LINEAR,
			mag_filter = GL.LINEAR,
			wrap_s = GL.CLAMP_TO_EDGE,
			wrap_t = GL.CLAMP_TO_EDGE,
			fbo = true,
		}
	)
	Spring.Echo("Generated blank splattex")

	local vertSrc = [[
		void main(void)
		{
		  gl_TexCoord[0] = gl_MultiTexCoord0;
		  gl_Position    = gl_Vertex;
		}
	  ]]
	  
	local fragSrc = [[
        uniform sampler2D tex0; // unqualified heightfield
        uniform sampler2D tex1; // 2d normals
		uniform sampler2D tex2; // hard rock texture
		uniform sampler2D tex3; // flats texture
		uniform sampler2D tex4; // beach texture
		uniform sampler2D tex5; // mid-altitude flats
		uniform sampler2D tex6; // high-altitude flats
		uniform sampler2D tex7; // ramp/hill texture

		uniform float minHeight;
		uniform float maxHeight;

		// should these be uniforms?
		const float hardCliffMax = 1.0; // sharpest bot-blocking cliff
		const float hardCliffMin = 0.58778525229; // least sharp bot-blocking cliff

		const float softCliffMax = hardCliffMin;
		const float softCliffMin = 0.30901699437;


		vec2 rotate(vec2 v, float a) {
			float s = sin(a);
			float c = cos(a);
			mat2 m = mat2(c, -s, s, c);
			return m * v;
		}

		void main()
		{
			vec2 coord = vec2(gl_TexCoord[0].s,0.5*gl_TexCoord[0].t);
			vec4 norm = texture2D(tex1, coord);
            vec2 norm2d = vec2(norm.x, norm.a);
			float slope = length(norm2d);
			float factor = 0.0;
			float height = texture2D(tex0,coord).r;

			// tile somewhat
			coord = 8.0*coord;

			// base texture
			gl_FragColor = texture2D(tex2,coord);

			// ---- altitude textures ----

			// admix depths
			factor = smoothstep(-5.0,-17.0,height);
			gl_FragColor = mix(gl_FragColor,vec4(0.6,0.5,0.0,1.0),factor);

			// admix beaches
			factor = clamp(0.1*(10.0-abs(height)),0.0,1.0);
			gl_FragColor = mix(gl_FragColor,texture2D(tex4,coord),factor);

			// admix midlands
			factor = clamp(1.0-0.02*abs(height-150.0),0.0,1.0);
			gl_FragColor = mix(gl_FragColor,texture2D(tex5,coord),factor);

			// admix highlands
			factor = smoothstep(300.0,400.0,height);
			gl_FragColor = mix(gl_FragColor,texture2D(tex6,coord),factor);

			// ---- slope textures ----

			// admix ramps (maybe replace texture later)
			factor = 0.25*smoothstep(0.1, softCliffMin, slope);
			gl_FragColor = mix(gl_FragColor,texture2D(tex7,coord),factor);

			// admix soft cliffs (replace texture later)
			factor = 0.5*smoothstep(softCliffMin, softCliffMax, slope);
			gl_FragColor = mix(gl_FragColor,texture2D(tex7,coord),factor);

			// admix hard cliffs
			factor = smoothstep(hardCliffMin, hardCliffMax, slope);
			gl_FragColor = mix(gl_FragColor,texture2D(tex3,coord),factor);
		}
	]]

	local diffuseShader = glCreateShader({
		vertex = vertSrc,
		fragment = fragSrc,
		uniformInt = {
			tex0 = 0,
			tex1 = 1,
			tex2 = 2,
			tex3 = 3,
			tex4 = 4,
			tex5 = 5,
			tex6 = 6,
			tex7 = 7,
		},
	});


	Spring.Echo(gl.GetShaderLog())
	if(diffuseShader) then
		Spring.Echo("Diffuse shader created");
	else
		Spring.Echo("SHADER ERROR");
		Spring.Echo(gl.GetShaderLog())

		mapfullyprocessed = true
		return
	end

	local minHeightPos  = glGetUniformLocation(diffuseShader, 'minHeight')
	local maxHeightPos  = glGetUniformLocation(diffuseShader, 'maxHeight')

	
	local function DrawLoop()
		local loopCount = 0
		glColor(1, 1, 1, 1)
		local ago = Spring.GetTimer()
		
		Spring.Echo("Begin shader draw")

		glRenderToTexture(topFullTex, function ()			
			glUseShader(diffuseShader)
			glUniform(minHeightPos, minHeight)
			glUniform(maxHeightPos, maxHeight)
			glTexture(0, "$heightmap")
			glTexture(0, false)
			glTexture(1,"$normals")
			glTexture(1, false)	
			glTexture(2,":l:unittextures/tacticalview/thornworld/diffuse/flats.png");
			glTexture(2, false)
			glTexture(3,":l:unittextures/tacticalview/thornworld/diffuse/cliffs.png");
			glTexture(3, false)
			glTexture(4,":l:unittextures/tacticalview/thornworld/diffuse/beach.jpg");
			glTexture(4, false)
			glTexture(5,":l:unittextures/tacticalview/thornworld/diffuse/midlands.jpg");
			glTexture(5, false)
			glTexture(6,":l:unittextures/tacticalview/thornworld/diffuse/highlands.png");
			glTexture(6, false)
			glTexture(7,":l:unittextures/tacticalview/thornworld/diffuse/slopes.png");
			glTexture(7, false)
			gl.TexRect(-1,-1,1,0,false,true)
			glUseShader(0)
		end)

		Sleep()
		Spring.ClearWatchDogTimer()
		glTexture(false)
		
		local cur = Spring.GetTimer()
		Spring.Echo("FullTex rendered in: "..(Spring.DiffTimers(cur, ago, true)))
		local ago2 = Spring.GetTimer()
		gl.Blending(GL.ONE, GL.ZERO)

		Sleep()
		Spring.ClearWatchDogTimer()
		cur = Spring.GetTimer()
		Spring.Echo("Splattex rendered in: "..(Spring.DiffTimers(cur, ago2, true)))
		glColor(1, 1, 1, 1)


		Spring.Echo("Starting to render SquareTextures")
		local fulltex = gl.CreateTexture(MAP_X/BLOCK_SIZE, MAP_Z/BLOCK_SIZE,
			{
				border = false,
				min_filter = GL.LINEAR,
				mag_filter = GL.LINEAR,
				wrap_s = GL.CLAMP_TO_EDGE,
				wrap_t = GL.CLAMP_TO_EDGE,
				fbo = true,
			}
		)
		local splattex = USE_SHADING_TEXTURE and gl.CreateTexture(MAP_X/BLOCK_SIZE, MAP_Z/BLOCK_SIZE,
			{
				format = GL_RGBA32F,
				border = false,
				min_filter = GL.LINEAR,
				mag_filter = GL.LINEAR,
				wrap_s = GL.CLAMP_TO_EDGE,
				wrap_t = GL.CLAMP_TO_EDGE,
				fbo = true,
			}
		)
		
		gl.Blending(false)
		glTexture(topFullTex)
		glRenderToTexture(fulltex , LowerHalfRotateSymmetry)
		
		if topSplattex then
			glTexture(topSplattex)
			glRenderToTexture(splattex , LowerHalfRotateSymmetry)
		end

		local texOut = fulltex
		
		GG.mapgen_squareTexture  = {}
		GG.mapgen_currentTexture = {}
		local ago3 = Spring.GetTimer()
		for x = 0, MAP_X - 1, SQUARE_SIZE do -- Create sqr textures for each sqr
			local sx = floor(x/SQUARE_SIZE)
			GG.mapgen_squareTexture[sx]  = {}
			GG.mapgen_currentTexture[sx] = {}
			for z = 0, MAP_Z - 1, SQUARE_SIZE do
				local sz = floor(z/SQUARE_SIZE)
				local squareTex = glCreateTexture(SQUARE_SIZE/BLOCK_SIZE, SQUARE_SIZE/BLOCK_SIZE,
					{
						border = false,
						min_filter = GL.LINEAR,
						mag_filter = GL.LINEAR,
						wrap_s = GL.CLAMP_TO_EDGE,
						wrap_t = GL.CLAMP_TO_EDGE,
						fbo = true,
					}
				)
				local origTex = glCreateTexture(SQUARE_SIZE, SQUARE_SIZE,
					{
						border = false,
						min_filter = GL.LINEAR,
						mag_filter = GL.LINEAR,
						wrap_s = GL.CLAMP_TO_EDGE,
						wrap_t = GL.CLAMP_TO_EDGE,
						fbo = true,
					}
				)
				local curTex = glCreateTexture(SQUARE_SIZE, SQUARE_SIZE,
					{
						border = false,
						min_filter = GL.LINEAR,
						mag_filter = GL.LINEAR,
						wrap_s = GL.CLAMP_TO_EDGE,
						wrap_t = GL.CLAMP_TO_EDGE,
						fbo = true,
					}
				)
				glTexture(texOut)
				
				glRenderToTexture(squareTex, DrawTextureOnSquare, 0, 0, SQUARE_SIZE, x/MAP_X, z/MAP_Z, SQUARE_SIZE/MAP_X, SQUARE_SIZE/MAP_Z)
				glRenderToTexture(origTex  , DrawTextureOnSquare, 0, 0, SQUARE_SIZE, x/MAP_X, z/MAP_Z, SQUARE_SIZE/MAP_X, SQUARE_SIZE/MAP_Z)
				glRenderToTexture(curTex   , DrawTextureOnSquare, 0, 0, SQUARE_SIZE, x/MAP_X, z/MAP_Z, SQUARE_SIZE/MAP_X, SQUARE_SIZE/MAP_Z)
				
				GG.mapgen_squareTexture[sx][sz]  = origTex
				GG.mapgen_currentTexture[sx][sz] = curTex
				GG.mapgen_fulltex = fulltex
				
				glTexture(false)
				gl.GenerateMipmap(squareTex)
				Spring.SetMapSquareTexture(sx, sz, squareTex)
			end
		end
		cur = Spring.GetTimer()
		Spring.Echo("All squaretex rendered and applied in: "..(Spring.DiffTimers(cur, ago3, true)))

		Spring.SetMapShadingTexture("$grass", texOut)
		usedgrass = texOut
		Spring.SetMapShadingTexture("$minimap", texOut)
		usedminimap = texOut
		Spring.Echo("Applied grass and minimap textures")
		gl.DeleteTextureFBO(fulltex)
		
		if texOut and texOut ~= usedgrass and texOut ~= usedminimap then
			glDeleteTexture(texOut)
			texOut = nil
		end
		
		if false then
			texOut = splattex
			Spring.SetMapShadingTexture("$ssmf_splat_distr", texOut)
			usedsplat = texOut
			Spring.Echo("Applied splat texture")
			gl.DeleteTextureFBO(splattex)
			if texOut and texOut ~= usedsplat then
				glDeleteTexture(texOut)
				if splattex and texOut == splattex then
					splattex = nil
				end
				texOut = nil
			end
			if splattex and splattex ~= usedsplat then
				glDeleteTexture(splattex)
				splattex = nil
			end
		end
		local DrawEnd = Spring.GetTimer()
		Spring.Echo("map fully processed in: "..(Spring.DiffTimers(DrawEnd, DrawStart, true)))
		
		mapfullyprocessed = true
	end
	
	StartScript(DrawLoop)
end



--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function SetupTextureSet(textureSetName)
	local usetextureSet = textureSetName 
	local texturePath = 'unittextures/tacticalview/' .. usetextureSet.. '/'
	
	local added = 0
	local textures = {}
	
	added = added + 1
	textures[added] = {
		texture = texturePath.."m.png",
	}
	
	for i = 1, SPIDER_TEX do
		added = added + 1
		textures[added] = {
			texture = texturePath .. "n" .. i .. ".png",
		}
	end
	for i = 1, BOT_TEX do
		added = added + 1
		textures[added] = {
			texture = texturePath .. "b" .. i .. ".png",
		}
	end
	for i = 1, VEH_TEX do
		added = added + 1
		textures[added] = {
			texture = texturePath .. "v" .. i .. ".png",
		}
	end
	return textures
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local vehTexPool, botTexPool, spiderTexPool, uwTexPool
local mapTexX, mapTexZ, topTexX, topTexZ, topTexAlpha, splatTexX, splatTexZ, splatTexCol, mapHeight

function gadget:DrawGenesis()
	if mapfullyprocessed then
		gadgetHandler:RemoveGadget()
		return
	end
	
	if activeCoroutine then
		UpdateCoroutines()
	else
		SetMapTexture(texturePool, mapTexX, mapTexZ, topTexX, topTexZ, topTexAlpha, splatTexX, splatTexZ, splatTexCol, mapHeight)
	end
end

function gadget:MousePress(x, y, button)
	return (button == 1) and (not mapfullyprocessed)
end

