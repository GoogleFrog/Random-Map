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
		layer     = 10, -- -10,
		enabled   = true, --  loaded by default?
		handler   = true, --sprang
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

local BLOCK_SIZE  = 8
local DRAW_OFFSET = 2 * BLOCK_SIZE/MAP_Z - 1

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

local GL_RGBA = 0x1908
local GL_RGBA16F = 0x881A
local GL_RGBA32F = 0x8814

local floor  = math.floor
local random = math.random

local SPLAT_DETAIL_TEX_POOL = {
	{1,0,0,1}, --R
	{0,1,0,1}, --G
	{0,0,1,1}, --B
	{0,0,0,1}, --A
}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function drawTextureOnSquare(x, z, size, sx, sz, xsize, zsize)
	local x1 = 2*x/SQUARE_SIZE - 1
	local z1 = 2*z/SQUARE_SIZE - 1
	local x2 = 2*(x+size)/SQUARE_SIZE - 1
	local z2 = 2*(z+size)/SQUARE_SIZE - 1
	glTexRect(x1, z1, x2, z2, sx, sz, sx+xsize, sz+zsize)
end

local function drawTextureOnMapTex(x, z)
	local x1 = 2*x/MAP_X - 1
	local z1 = 2*z/MAP_Z - 1
	local x2 = 2*(x+BLOCK_SIZE)/MAP_X - 1
	local z2 = 2*(z+BLOCK_SIZE)/MAP_Z - 1
	glTexRect(x1, z1, x2, z2)
end

local function drawSplatTextureOnMapTex(x, z)
	local x1 = 2*x/MAP_X - 1
	local z1 = 2*z/MAP_Z - 1
	local x2 = 2*(x+BLOCK_SIZE)/MAP_X - 1
	local z2 = 2*(z+BLOCK_SIZE)/MAP_Z - 1
	glRect(x1, z1, x2, z2)
end

local function drawtexblockontex(x, z)
	glTexRect(x*MAP_FAC_X - 1, z*MAP_FAC_Z - 1, x*MAP_FAC_X + DRAW_OFFSET, z*MAP_FAC_Z + DRAW_OFFSET)
end

local function drawcolorblockontex(x, z)
	glRect(x*MAP_FAC_X -1, z*MAP_FAC_Z - 1, x*MAP_FAC_X + DRAW_OFFSET, z*MAP_FAC_Z + DRAW_OFFSET)
end

local function drawCopySquare()
	glTexRect(-1, 1, 1, -1)
end

local function drawRectOnTex(x1, z1, x2, z2, sx1, sz1, sx2, sz2)
	glTexRect(x1, z1, x2, z2, sx1, sz1, sx2, sz2)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function GetTextureSet(textureSetName)
	local usetextureSet = textureSetName .. '/'
	local texturePath = 'unittextures/tacticalview/' .. usetextureSet
	return {
		[1] = {
			texture = texturePath.."v1.png",
			size = 92,
			tile = 1,
		},
		[2] = {
			texture = texturePath.."v2.png",
			size = 92,
			tile = 1,
		},
		[3] = {
			texture = texturePath.."v3.png",
			size = 92,
			tile = 1,
		},
		[4] = {
			texture = texturePath.."v4.png",
			size = 92,
			tile = 1,
		},
		[5] = {
			texture = texturePath.."v5.png",
			size = 92,
			tile = 1,
		},
		[6] = {
			texture = texturePath.."b1.png",
			size = 92,
			tile = 1,
		},
		[7] = {
			texture = texturePath.."b2.png",
			size = 92,
			tile = 1,
		},
		[8] = {
			texture = texturePath.."b3.png",
			size = 92,
			tile = 1,
		},
		[9] = {
			texture = texturePath.."b4.png",
			size = 92,
			tile = 1,
		},
		[10] = {
			texture = texturePath.."b5.png",
			size = 92,
			tile = 1,
		},
		[11] = {
			texture = texturePath.."n1.png",
			size = 92,
			tile = 1,
		},
		[12] = {
			texture = texturePath.."n2.png",
			size = 92,
			tile = 1,
		},
		[13] = {
			texture = texturePath.."n3.png",
			size = 92,
			tile = 1,
		},
		[14] = {
			texture = texturePath.."n4.png",
			size = 92,
			tile = 1,
		},
		[15] = {
			texture = texturePath.."n5.png",
			size = 92,
			tile = 1,
		},
		[16] = {
			texture = texturePath.."m.png",
			size = 92,
			tile = 1,
		},
		[17] = {
			texture = texturePath.."uwv.png",
			size = 92,
			tile = 1,
		},
		[18] = {
			texture = texturePath.."uwb.png",
			size = 92,
			tile = 1,
		},
		[19] = {
			texture = texturePath.."uwn.png",
			size = 92,
			tile = 1,
		},
		[20] = {
			texture = texturePath.."uwm.png",
			size = 92,
			tile = 1,
		},
	}
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function SetMapTexture(texturePool, mapTexX, mapTexZ, splatTexX, splatTexZ)
	local DrawStart = Spring.GetTimer()
	local usedsplat
	local usedgrass
	local usedminimap
	
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
	if not fulltex then
		return
	end
	
	Spring.Echo("Generated blank fulltex")
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
	Spring.Echo("Generated blank splattex")
	
	local ago = Spring.GetTimer()
	for i = 1, #texturePool do
		local texX = mapTexX[i]
		local texZ = mapTexZ[i]
		if texX then
			glTexture(texturePool[i].texture)
			for j = 1, #texX do
				glRenderToTexture(fulltex, drawtexblockontex, texX[j], texZ[j])
			end
		end
	end
	glTexture(false)
	
	local cur = Spring.GetTimer()
	Spring.Echo("FullTex rendered in: "..(Spring.DiffTimers(cur, ago, true)))
	
	if USE_SHADING_TEXTURE then
		local ago2 = Spring.GetTimer()
		for i = 1, #SPLAT_DETAIL_TEX_POOL do
			local texX = splatTexX[i]
			local texZ = splatTexZ[i]
			if texX then
				glColor(SPLAT_DETAIL_TEX_POOL[i])
				for j = 1, #texX do
					glRenderToTexture(splattex, drawcolorblockontex, texX[j], texZ[j])
					Spring.ClearWatchDogTimer()
				end
			end
		end
		cur = Spring.GetTimer()
		Spring.Echo("Splattex rendered in: "..(Spring.DiffTimers(cur, ago2, true)))
		glColor(1, 1, 1, 1)
	end
	
	local texOut = fulltex
	Spring.Echo("Starting to render SquareTextures")
	
	local ago3 = Spring.GetTimer()
	for x = 0, MAP_X - 1, SQUARE_SIZE do -- Create sqr textures for each sqr
		for z = 0, MAP_Z - 1, SQUARE_SIZE do
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
			glTexture(texOut)
			glRenderToTexture(squareTex, drawTextureOnSquare, 0, 0, SQUARE_SIZE, x/MAP_X, z/MAP_Z, SQUARE_SIZE/MAP_X, SQUARE_SIZE/MAP_Z)
			glTexture(false)
			gl.GenerateMipmap(squareTex)
			Spring.SetMapSquareTexture((x/SQUARE_SIZE),(z/SQUARE_SIZE), squareTex)
		end
	end
	cur = Spring.GetTimer()
	Spring.Echo("All squaretex rendered and applied in: "..(Spring.DiffTimers(cur, ago3, true)))
	
	if USE_SHADING_TEXTURE then
		Spring.SetMapShadingTexture("$grass", texOut)
		usedgrass = texOut
		Spring.SetMapShadingTexture("$minimap", texOut)
		usedminimap = texOut
		Spring.Echo("Applied grass and minimap textures")
	end
	gl.DeleteTextureFBO(fulltex)
	
	if fulltex and fulltex ~= usedgrass and fulltex ~= usedminimap then -- delete unused textures
		glDeleteTexture(fulltex)
		if texOut and texOut == fulltex then
			texOut = nil
		end
		fulltex = nil
	end
	if texOut and texOut ~= usedgrass and texOut ~= usedminimap then
		glDeleteTexture(texOut)
		texOut = nil
	end
	
	if USE_SHADING_TEXTURE then
		texOut = splattex
		Spring.SetMapShadingTexture("$ssmf_splat_distr", texOut)
		usedsplat = texOut
		Spring.Echo("Applied splat texture")
		gl.DeleteTextureFBO(splattex)
		if texOut and texOut ~= usedsplat then
			glDeleteTexture(texOut)
			if splattex and texOut == splattex then
				splattex = nile
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
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function InitializeTextures(useSplat, typemap)
	local ago = Spring.GetTimer()
	local mapTexX = {}
	local mapTexZ = {}
	local splatTexX = {}
	local splatTexZ = {}
	for x = 0, MAP_X - 1, BLOCK_SIZE do
		for z = 0, MAP_Z - 1, BLOCK_SIZE do
			local TANK = SpTestMoveOrder(UnitDefNames["vehassault"].id, x, 0,z, 0,0,0, true, false, true)
			--local TANK = SpTestMoveOrder(UnitDefNames["testvehicle"].id, x, 0,z, 0,0,0, true, false, true)
			local KBOT = SpTestMoveOrder(UnitDefNames["cloakriot"].id, x, 0,z, 0,0,0, true, false, true)
			local METAL = SpGetMetalAmount(floor(x/16), floor(z/16)) > 0
			local UW = SpTestBuildOrder(UnitDefNames["staticsonar"].id, x, 0,z, 0) == 0	
			local tex = SlopeType(x, z, TANK, KBOT, METAL, UW, typemap)
			
			mapTexX[tex] = mapTexX[tex] or {}
			mapTexZ[tex] = mapTexZ[tex] or {}
			mapTexX[tex][#mapTexX[tex] + 1] = x
			mapTexZ[tex][#mapTexZ[tex] + 1] = z
			
			if useSplat then
				local splat = SplatSlopeType(x, z, TANK, KBOT, METAL, UW, typemap)
				splatTexX[splat] = splatTexX[splat] or {}
				splatTexZ[splat] = splatTexZ[splat] or {}
				splatTexX[splat][#splatTexX[splat] + 1] = x
				splatTexZ[splat][#splatTexZ[splat] + 1] = z
			end
		end
	end
	local cur = Spring.GetTimer()
	Spring.Echo("Map scanned in: "..(Spring.DiffTimers(cur, ago, true)))
	
	return mapTexX, mapTexZ, splatTexX, splatTexZ
end

function SlopeType(x,z,t,k,m,uw,e)
	if uw then
		if m then
			return 16
		elseif t then
			return random(1,5)
		elseif k then
			return random(6,10)
		else
			return random(11,15)
		end
	else
		if m then
			return 20
		elseif t then
			return 17
		elseif k then
			return 18
		else
			return 19
		end
	end
end

function SplatSlopeType(x,z,t,k,m,uw,e)
	if uw then
		if m then
			return 1
		elseif e == "moon" then
			return random(1,2)
		elseif t then
			if e == "desert" then
				return (random(1,2) == 2) and (random(1,2) == 2) and (random(1,2) == 2) and (random(1,2) == 2) and 2 or 1
			else
				return (1)
			end
		elseif k then
			if e == "arctic" then
				return random(1,2)
			elseif e == "temperate" then
				return (random(1,2) == 1) and (random(1,2) == 1) and (random(1,2) == 1) and 1 or 2
			else
				return (2)
			end
		else
			return 2
		end
	else
		if m then
			return 3
		elseif e == "moon" then
			return random(1,2)
		elseif e == "arctic" then
			return (random(1,2) == 1) and (random(1,2) == 1) and (random(1,2) == 1) and 1 or 2
		elseif t then
			return 3
		elseif k then
			return 3
		else
			return 3
		end
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local texturePool
local mapTexX, mapTexZ, splatTexX, splatTexZ

function gadget:DrawGenesis()
	if initialized ~= true then
		return
	end
	if mapfullyprocessed == true then
		return
	end
	mapfullyprocessed = true
	SetMapTexture(texturePool, mapTexX, mapTexZ, splatTexX, splatTexZ)
end

function gadget:Initialize()
	if (not gl.RenderToTexture) then --super bad graphic driver
		return
	end
	texturePool = GetTextureSet(Spring.GetGameRulesParam("typemap"))
	mapTexX, mapTexZ, splatTexX, splatTexZ =  InitializeTextures(USE_SHADING_TEXTURE, Spring.GetGameRulesParam("typemap"))
	
	initialized = true
	activestate = true
	--sprang
	gadgetHandler:DisableGadget("Terrain Texture Handler")
end
