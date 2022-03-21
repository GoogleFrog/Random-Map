--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
if (gadgetHandler:IsSyncedCode()) then
	return
end
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
	return {
		name      = "Map Texture Generator",
		desc      = "Applies basic textures on maps based on slopemap",
		author    = "Anarchid",
		date      = "26 September 2021",
		license   = "GNU GPL, v2 or later",
		layer     = 10,
		enabled   = (gl.CreateShader and true) or false, --  loaded by default?
	}
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local MAP_X = Game.mapSizeX
local MAP_Z = Game.mapSizeZ

local SQUARE_SIZE = 1024
local SQUARES_X = MAP_X/SQUARE_SIZE
local SQUARES_Z = MAP_Z/SQUARE_SIZE

local VEH_NORMAL      = 0.892
local BOT_NORMAL_PLUS = 0.85
local BOT_NORMAL      = 0.585
local SHALLOW_HEIGHT  = -22

local USE_SHADING_TEXTURE = (Spring.GetConfigInt("AdvMapShading") == 1)

local spSetMapSquareTexture = Spring.SetMapSquareTexture
local spGetMapSquareTexture = Spring.GetMapSquareTexture
local spGetGroundHeight     = Spring.GetGroundHeight
local spGetGroundOrigHeight = Spring.GetGroundOrigHeight

local glTexture         = gl.Texture
local glColor           = gl.Color
local glCreateTexture   = gl.CreateTexture
local glTexRect         = gl.TexRect
local glRect            = gl.Rect
local glDeleteTexture   = gl.DeleteTexture
local glDeleteShader    = gl.DeleteShader
local glRenderToTexture = gl.RenderToTexture
local glCreateShader    = gl.CreateShader
local glUseShader       = gl.UseShader
local glGetUniformLocation   = gl.GetUniformLocation
local glUniform              = gl.Uniform

local GL_RGBA = 0x1908

local GL_RGBA16F = 0x881A
local GL_RGBA32F = 0x8814

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

local function LowerHalfRotateSymmetry()
	glTexRect(-1, -1, 1, 1, 0, 0, 1, 1)
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

	local fulltex = gl.CreateTexture(MAP_X, MAP_Z,
		{
			border = false,
			min_filter = GL.LINEAR,
			mag_filter = GL.LINEAR,
			wrap_s = GL.CLAMP_TO_EDGE,
			wrap_t = GL.CLAMP_TO_EDGE,
			fbo = true,
		}
	)

	-- specular probably doesn't need to be entirely full reso tbf
	local spectex = gl.CreateTexture(MAP_X/4, MAP_Z/4,
		{
			border = false,
			min_filter = GL.LINEAR,
			mag_filter = GL.LINEAR,
			wrap_s = GL.CLAMP_TO_EDGE,
			wrap_t = GL.CLAMP_TO_EDGE,
			fbo = true,
		}
	)
	
	local splattex = USE_SHADING_TEXTURE and gl.CreateTexture(MAP_X/16, MAP_Z/16,
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
	
	Spring.Echo("Generated blank fulltex")
	Spring.Echo("Generated blank splattex")

	local vertSrc = [[
		void main(void)
		{
		  gl_TexCoord[0] = gl_MultiTexCoord0;
		  gl_Position    = gl_Vertex;
		}
	  ]]

	local fragSrc = VFS.LoadFile("shaders/map_diffuse_generator.glsl");
	local fragSrc_dnts = VFS.LoadFile("shaders/dnts.glsl");

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
			tex8 = 8,
			tex9 = 9,
			tex10 = 10,
			tex11 = 11,
			tex12 = 12,
			tex13 = 13,
		},
	})
	
	local dntsShader = glCreateShader({
		vertex = vertSrc,
		fragment = fragSrc_dnts,
		uniformInt = {
			tex0 = 0,
			tex1 = 1,
		},
	})

	Spring.Echo(gl.GetShaderLog())
	if(diffuseShader and dntsShader) then
		Spring.Echo("Diffuse shader created");
	else
		Spring.Echo("SHADER ERROR");
		Spring.Echo(gl.GetShaderLog())

		mapfullyprocessed = true
		return
	end

	local function DrawLoop()
		gl.Blending(false)
		local loopCount = 0
		glColor(1, 1, 1, 1)
		local ago = Spring.GetTimer()
		
		Spring.Echo("Begin shader draw")

		glRenderToTexture(fulltex, function ()
			glUseShader(diffuseShader)
			glTexture(0, "$heightmap")
			glTexture(0, false)
			glTexture(1,"$normals")
			glTexture(1, false)	
			glTexture(2,":l:unittextures/tacticalview/terran/diffuse/flats.png");
			glTexture(2, false)
			glTexture(3,":l:unittextures/tacticalview/terran/diffuse/cliffs.png");
			glTexture(3, false)
			glTexture(4,":l:unittextures/tacticalview/terran/diffuse/beach.jpg");
			glTexture(4, false)
			glTexture(5,":l:unittextures/tacticalview/terran/diffuse/midlands.png");
			glTexture(5, false)
			glTexture(6,":l:unittextures/tacticalview/terran/diffuse/highlands.png");
			glTexture(6, false)
			glTexture(7,":l:unittextures/tacticalview/terran/diffuse/slopes.png");
			glTexture(7, false)
			glTexture(8,":l:unittextures/tacticalview/terran/diffuse/ramps.png");
			glTexture(8, false)
			glTexture(9,":l:unittextures/tacticalview/terran/diffuse/cloudgrass.png");
			glTexture(9, false)
			glTexture(10,":l:unittextures/tacticalview/terran/diffuse/cloudgrassdark.png");
			glTexture(10, false)
			glTexture(11,":l:unittextures/tacticalview/terran/diffuse/sand.png");
			glTexture(11, false)
			glTexture(12,":l:unittextures/tacticalview/terran/height/ramps.png");
			glTexture(12, false)
			glTexture(13,":l:unittextures/tacticalview/terran/height/cliffs.png");
			glTexture(13, false)
			gl.TexRect(-1,-1,1,1,false,true)
			glUseShader(0)
		end)

		Sleep()
		Spring.ClearWatchDogTimer()

		glDeleteTexture(":l:unittextures/tacticalview/terran/diffuse/flats.png");
		glDeleteTexture(":l:unittextures/tacticalview/terran/diffuse/cliffs.png");
		glDeleteTexture(":l:unittextures/tacticalview/terran/diffuse/beach.jpg");
		glDeleteTexture(":l:unittextures/tacticalview/terran/diffuse/midlands.png");
		glDeleteTexture(":l:unittextures/tacticalview/terran/diffuse/highlands.png");
		glDeleteTexture(":l:unittextures/tacticalview/terran/diffuse/slopes.png");
		glDeleteTexture(":l:unittextures/tacticalview/terran/diffuse/ramps.png");
		glDeleteTexture(":l:unittextures/tacticalview/terran/diffuse/cloudgrass.png");
		glDeleteTexture(":l:unittextures/tacticalview/terran/diffuse/cloudgrassdark.png");
		glDeleteTexture(":l:unittextures/tacticalview/terran/diffuse/sand.png");
		glTexture(false)

		local cur = Spring.GetTimer()
		Spring.Echo("FullTex rendered in: "..(Spring.DiffTimers(cur, ago, true)))
		local ago2 = Spring.GetTimer()
		--gl.Blending(GL.ONE, GL.ZERO)


		Sleep()
		Spring.ClearWatchDogTimer()
		cur = Spring.GetTimer()
		glColor(1, 1, 1, 1)


		Spring.Echo("Starting to render DNTS-splattex")
		glRenderToTexture(splattex, function ()
			glUseShader(dntsShader)
			gl.Blending(false)
			glTexture(0, "$heightmap")
			glTexture(0, false)
			glTexture(1,"$normals")
			glTexture(1, false)
			gl.TexRect(-1,-1,1,1,false,true)
			glUseShader(0)
		end)
		gl.Blending(false)
		glTexture(false)
		glDeleteShader(dntsShader);
		glRenderToTexture(spectex, function ()
			glUseShader(diffuseShader)
			glTexture(0, "$heightmap")
			glTexture(0, false)
			glTexture(1,"$normals")
			glTexture(1, false)
			glTexture(2,":l:unittextures/tacticalview/terran/specular/flats.png");
			glTexture(2, false)
			glTexture(3,":l:unittextures/tacticalview/terran/specular/cliffs.png");
			glTexture(3, false)
			glTexture(4,":l:unittextures/tacticalview/terran/specular/beach.png");
			glTexture(4, false)
			glTexture(5,":l:unittextures/tacticalview/terran/specular/cloudgrass.png");
			glTexture(5, false)
			glTexture(6,":l:unittextures/tacticalview/terran/specular/highlands.png");
			glTexture(6, false)
			glTexture(7,":l:unittextures/tacticalview/terran/specular/slopes.png");
			glTexture(7, false)
			glTexture(8,":l:unittextures/tacticalview/terran/specular/ramps.png");
			glTexture(8, false)
			glTexture(9,":l:unittextures/tacticalview/terran/specular/cloudgrass.png");
			glTexture(9, false)
			glTexture(10,":l:unittextures/tacticalview/terran/specular/cloudgrassdark.png");
			glTexture(10, false)
			glTexture(11,":l:unittextures/tacticalview/terran/specular/sand.png");
			glTexture(11, false)
			glTexture(12,":l:unittextures/tacticalview/terran/height/ramps.png");
			glTexture(12, false)
			glTexture(13,":l:unittextures/tacticalview/terran/height/cliffs.png");
			glTexture(13, false)
			gl.TexRect(-1,-1,1,1,false,true)
			glUseShader(0)
		end)
		glDeleteTexture(":l:unittextures/tacticalview/terran/specular/flats.png");
		glDeleteTexture(":l:unittextures/tacticalview/terran/specular/cliffs.png");
		glDeleteTexture(":l:unittextures/tacticalview/terran/specular/beach.png");
		glDeleteTexture(":l:unittextures/tacticalview/terran/specular/cloudgrass.png");
		glDeleteTexture(":l:unittextures/tacticalview/terran/specular/highlands.png");
		glDeleteTexture(":l:unittextures/tacticalview/terran/specular/slopes.png");
		glDeleteTexture(":l:unittextures/tacticalview/terran/specular/ramps.png");
		glDeleteTexture(":l:unittextures/tacticalview/terran/specular/cloudgrass.png");
		glDeleteTexture(":l:unittextures/tacticalview/terran/specular/cloudgrassdark.png");
		glDeleteTexture(":l:unittextures/tacticalview/terran/specular/sand.png");
		glTexture(false)
		glDeleteShader(diffuseShader);
		
		cur = Spring.GetTimer()
		Spring.Echo("Specular and Splat rendered in "..(Spring.DiffTimers(cur, ago2, true)))

		Spring.Echo("Starting to render SquareTextures")
		
		gl.Blending(false)

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
				local squareTex = glCreateTexture(SQUARE_SIZE, SQUARE_SIZE,
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

		Spring.SetMapShadingTexture("$ssmf_specular", spectex)
		Spring.SetMapShadingTexture("$ssmf_splat_distr", splattex)
		Spring.Echo("specular and splat applied")
	
		-- Spring.SetMapShadingTexture("$grass", texOut)

		usedgrass = texOut
		Spring.SetMapShadingTexture("$minimap", texOut)
		usedminimap = texOut
		Spring.Echo("Applied grass and minimap textures")
		
		gl.DeleteTextureFBO(fulltex)
		
		if texOut and texOut ~= usedgrass and texOut ~= usedminimap then
			glDeleteTexture(texOut)
			texOut = nil
		end
		
		local DrawEnd = Spring.GetTimer()
		Spring.Echo("map fully processed in: "..(Spring.DiffTimers(DrawEnd, DrawStart, true)))
		
		mapfullyprocessed = true
	end
	
	StartScript(DrawLoop)
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
