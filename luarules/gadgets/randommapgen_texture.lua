
function gadget:GetInfo()
  return {
    name      = "Unified Texturing",
    desc      = "Applies basic textures on maps based on slopemap",
    author    = "Google Frog (edited for randommapgen purposes by Doo)",
    date      = "25 June 2012, edited 2018", --24 August 2013
    license   = "GNU GPL, v2 or later",
    layer     = -10,
    enabled   = false --  loaded by default?
  }
end

local useBlur = false

local mapSizeX = Game.mapSizeX
local mapSizeZ = Game.mapSizeZ

local MAP_WIDTH = mapSizeX
local MAP_HEIGHT = mapSizeZ
local SQUARE_SIZE = 1024
local SQUARES_X = MAP_WIDTH/SQUARE_SIZE
local SQUARES_Z = MAP_HEIGHT/SQUARE_SIZE
local UHM_WIDTH = 64
local UHM_HEIGHT = 64
local UHM_X = UHM_WIDTH/MAP_WIDTH
local UHM_Z = UHM_HEIGHT/MAP_HEIGHT
local BLOCK_SIZE = 16
local drawOffset = 2 * BLOCK_SIZE/mapSizeZ - 1 
local mapSizeFacX = 2/mapSizeX
local mapSizeFacZ = 2/mapSizeX

local spSetMapSquareTexture = Spring.SetMapSquareTexture
local spGetMapSquareTexture = Spring.GetMapSquareTexture
local spGetMyTeamID         = Spring.GetMyTeamID
local spGetGroundHeight     = Spring.GetGroundHeight
local spGetGroundOrigHeight = Spring.GetGroundOrigHeight
local SpGetMetalAmount = Spring.GetMetalAmount
local floor = math.floor
local rand = math.random
local SpTestMoveOrder = Spring.TestMoveOrder
local SpTestBuildOrder = Spring.TestBuildOrder
if (gadgetHandler:IsSyncedCode()) then

else
local useShadingTextures = Spring.GetConfigInt("AdvMapShading") == 1
local sqrTex = {}
local glTexture = gl.Texture
local glColor = gl.Color
local glCreateTexture = gl.CreateTexture
local glTexRect = gl.TexRect
local glRect = gl.Rect
local glDeleteTexture = gl.DeleteTexture
local glRenderToTexture = gl.RenderToTexture
local CallAsTeam = CallAsTeam
local textureSet = {'desert/', 'temperate/', 'arctic/', 'moon/'}
local usetextureSet = textureSet[rand(1,4)]
local texturePath = 'unittextures/tacticalview/'..usetextureSet
local splatTex = {}
local TEXTURE_COUNT = 20
local splatDetailTexPool = {
	{1,0,0,1}, --R
	{0,1,0,1}, --G
	{0,0,1,1}, --B
	{0,0,0,1}, --A
}
local texturePool = {
	-- [0] == original map texture
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

-- local LuaShader = VFS.Include("LuaRules/gadgets/libs/LuaShader.lua")
-- local GaussianBlur = VFS.Include("LuaRules/gadgets/libs/GaussianBlur.lua")
local GL_RGBA = 0x1908
local GL_RGBA16F = 0x881A
local GL_RGBA32F = 0x8814
local gb
local texIn, texOut

local mapTex = {} -- 2d array of textures

local blockStateMap = {} -- keeps track of drawn texture blocks.
local chunkMap = {} -- map of UHM chunk that stores pending changes.
local chunkUpdateList = {count = 0, data = {}} -- list of chuncks to update
local chunkUpdateMap = {} -- map of chunks which are in list. Prevent duplicate entry if UHMU is called twice

local syncedHeights = {} -- list of synced heightmap point values

local UMHU_updatequeue = {} -- send update data from gadget:UnsyncedHeightMapUpdate() to gadget:DrawWorld()


local function drawTextureOnSquare(x,z,size,sx,sz,xsize, zsize)
	local x1 = 2*x/SQUARE_SIZE - 1
	local z1 = 2*z/SQUARE_SIZE - 1
	local x2 = 2*(x+size)/SQUARE_SIZE - 1
	local z2 = 2*(z+size)/SQUARE_SIZE - 1
	glTexRect(x1,z1,x2,z2,sx,sz,sx+xsize,sz+zsize)
end

local function drawTextureOnMapTex(x,z)
	local x1 = 2*x/mapSizeX - 1
	local z1 = 2*z/mapSizeZ - 1
	local x2 = 2*(x+BLOCK_SIZE)/mapSizeX - 1
	local z2 = 2*(z+BLOCK_SIZE)/mapSizeZ - 1
	glTexRect(x1,z1,x2,z2)
end

local function drawSplatTextureOnMapTex(x,z)
	local x1 = 2*x/mapSizeX - 1
	local z1 = 2*z/mapSizeZ - 1
	local x2 = 2*(x+BLOCK_SIZE)/mapSizeX - 1
	local z2 = 2*(z+BLOCK_SIZE)/mapSizeZ - 1
	glRect(x1,z1,x2,z2)
end

local function drawtexblockontex(x,z)
	glTexRect(x*mapSizeFacX -1,z*mapSizeFacZ - 1,x*mapSizeFacX + drawOffset,z*mapSizeFacZ + drawOffset)
end

local function drawcolorblockontex(x,z)
	glRect(x*mapSizeFacX -1,z*mapSizeFacZ - 1,x*mapSizeFacX + drawOffset,z*mapSizeFacZ + drawOffset)
end

local function drawCopySquare()
	glTexRect(-1,1,1,-1)
end
local function drawRectOnTex(x1,z1,x2,z2,sx1,sz1, sx2,sz2)
	glTexRect(x1,z1,x2,z2,sx1,sz1, sx2,sz2)
end

function SetTextureSet(textureSetName)
	usetextureSet = textureSetName..'/'
	texturePath = 'unittextures/tacticalview/'..usetextureSet
	texturePool = {
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

-- function GaussianInitialize(fullTex, strength)

	-- texIn = fullTex
	-- texOut = gl.CreateTexture(SQUARE_SIZE,SQUARE_SIZE,
	-- {
		-- format = GL_RGBA16F,
		-- border = false,
		-- min_filter = GL.LINEAR,
		-- mag_filter = GL.LINEAR,
		-- wrap_s = GL.CLAMP_TO_EDGE,
		-- wrap_t = GL.CLAMP_TO_EDGE,
		-- fbo = true,
	-- })

	-- -- (texIn, texOut, unusedTexId, downScale, linearSampling, sigma, halfKernelSize, valMult, repeats, blurTexIntFormat)
	-- gb = GaussianBlur({
		-- texIn = texIn,
		-- texOut = texOut,
		-- unusedTexId = nil,
		-- downScale = 2,
		-- linearSampling = true,
		-- sigma = 3.0/BLOCK_SIZE,
		-- halfKernelSize = 5,
		-- valMult = 1.0,
		-- repeats = 2,
		-- blurTexIntFormat = GL_RGBA16F})
-- end

function gadget:DrawGenesis()
	if initialized ~= true then
		return
	end
	if mapfullyprocessed == true then
		return
	end
	local DrawStart = Spring.GetTimer()
	-- if useBlur == true and not (gl.CreateShader) then
		-- useBlur = false
	-- end
	local usedsplat
	local usedgrass
	local usedminimap
	if not fulltex then -- create fullsize blank tex
		fulltex = gl.CreateTexture(mapSizeX/BLOCK_SIZE,mapSizeZ/BLOCK_SIZE,
		{
			border = false,
			min_filter = GL.LINEAR,
			mag_filter = GL.LINEAR,
			wrap_s = GL.CLAMP_TO_EDGE,
			wrap_t = GL.CLAMP_TO_EDGE,
			fbo = true,
		})
	end
	Spring.Echo("Generated blank fulltex")
	if useShadingTextures and not splattex then -- create fullsize blank tex
		splattex = gl.CreateTexture(mapSizeX/BLOCK_SIZE,mapSizeZ/BLOCK_SIZE,
		{
			format = GL_RGBA32F,
			border = false,
			min_filter = GL.LINEAR,
			mag_filter = GL.LINEAR,
			wrap_s = GL.CLAMP_TO_EDGE,
			wrap_t = GL.CLAMP_TO_EDGE,
			fbo = true,
		})
	end
	Spring.Echo("Generated blank splattex")
	local ago = Spring.GetTimer()
	for i = 1, 20 do
		glTexture(texturePool[i].texture)
		for k = 1, ctTEX[i]-1 do
			local pos = mapTex[i][k]
			gl.RenderToTexture(fulltex, drawtexblockontex, pos.x, pos.z)
		end
		glTexture(false)
	end
	local cur = Spring.GetTimer()
	Spring.Echo("FullTex rendered in: "..(Spring.DiffTimers(cur, ago, true)))
	if useShadingTextures  then
		local ago2 = Spring.GetTimer()
		for i = 1, 4 do
			glColor(splatDetailTexPool[i])
			for k = 1, ctsplat[i]-1 do
				local pos = splatTex[i][k]
				glRenderToTexture(splattex, drawcolorblockontex, pos.x, pos.z)
				Spring.ClearWatchDogTimer()
			end
			glColor(1,1,1,1)
		end
		cur = Spring.GetTimer()
		Spring.Echo("Splattex rendered in: "..(Spring.DiffTimers(cur, ago2, true)))
	end
	if not fulltex then
		return
	end
	-- if useBlur then
		-- GaussianInitialize(fulltex,3)
		-- gb:Initialize()
		-- gb:Execute()
	-- else
		texOut = fulltex
	-- end
	Spring.Echo("Starting to render SquareTextures")
	local ago3 = Spring.GetTimer()
	for x = 0,mapSizeX - 1, SQUARE_SIZE do -- Create sqr textures for each sqr
		for z = 0,mapSizeZ - 1, SQUARE_SIZE do
			sqrTex[x] = sqrTex[x] or {}
			sqrTex[x][z] = glCreateTexture(SQUARE_SIZE/BLOCK_SIZE,SQUARE_SIZE/BLOCK_SIZE,
			{
				border = false,
				min_filter = GL.LINEAR,
				mag_filter = GL.LINEAR,
				wrap_s = GL.CLAMP_TO_EDGE,
				wrap_t = GL.CLAMP_TO_EDGE,
				fbo = true,
			})
			glTexture(texOut)
			glRenderToTexture(sqrTex[x][z], drawTextureOnSquare, 0,0,SQUARE_SIZE, x/mapSizeX, z/mapSizeZ, SQUARE_SIZE/mapSizeX, SQUARE_SIZE/mapSizeZ)
			glTexture(false)
			gl.GenerateMipmap(sqrTex[x][z])
			Spring.SetMapSquareTexture((x/SQUARE_SIZE),(z/SQUARE_SIZE), sqrTex[x][z])
			sqrTex[x][z] = nil
		end
	end
	cur = Spring.GetTimer()
	Spring.Echo("All squaretex rendered and applied in: "..(Spring.DiffTimers(cur, ago3, true)))
	if useShadingTextures then
		Spring.SetMapShadingTexture("$grass", texOut)
		usedgrass = texOut
		Spring.SetMapShadingTexture("$minimap", texOut)
		usedminimap = texOut
		Spring.Echo("Applied grass and minimap textures")
	end
	-- if useBlur then
		-- gb:Finalize()
		-- gl.DeleteTextureFBO(texOut)
	-- end
	gl.DeleteTextureFBO(fulltex)
	if fulltex and fulltex ~= usedgrass and fulltex ~= usedminimap then -- delete unused textures
		glDeleteTexture(fulltex)
		if texOut and texOut == fulltex then -- texOut = fulltex if gl.CreateShader = nil
			texOut = nil
		end
		fulltex = nil
	end
	if texOut and texOut ~= usedgrass and texOut ~= usedminimap then
		glDeleteTexture(texOut)
		texOut = nil
	end	
	if useShadingTextures then
		-- if useBlur then
			-- GaussianInitialize(splattex,1.5)
			-- gb:Initialize()
			-- gb:Execute()
		-- else
			texOut = splattex
		-- end
		Spring.SetMapShadingTexture("$ssmf_splat_distr", texOut)
		usedsplat = texOut
		Spring.Echo("Applied splat texture")
		-- if useBlur then
			-- gb:Finalize()
			-- gl.DeleteTextureFBO(texOut)
		-- end
		gl.DeleteTextureFBO(splattex)
		if texOut and texOut~=usedsplat then
			glDeleteTexture(texOut)
			if splattex and texOut == splattex then -- texOut = splattex if gl.CreateShader = nil
				splattex = nile
			end
			texOut = nil
		end	
		if splattex and splattex~=usedsplat then
			glDeleteTexture(splattex)
			splattex = nil
		end	
	end
	mapfullyprocessed = true
	local DrawEnd = Spring.GetTimer()
	Spring.Echo("map fully processed in: "..(Spring.DiffTimers(DrawEnd, DrawStart, true)))
end

local function UpdateAll()
	local ago = Spring.GetTimer()
	local ENVIR = Spring.GetGameRulesParam("typemap")
	splatTex = {{},{},{},{}}	
	mapTex = {{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{}}
	ctsplat = {1,1,1,1}
	ctTEX = {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1}
	for x = 0, mapSizeX-1, BLOCK_SIZE do
		for z = 0, mapSizeZ-1, BLOCK_SIZE do
			local TANK = SpTestMoveOrder(UnitDefNames["vehassault"].id, x, 0,z, 0,0,0, true, false, true)
			local KBOT = SpTestMoveOrder(UnitDefNames["cloakriot"].id, x, 0,z, 0,0,0, true, false, true)
			local METAL = SpGetMetalAmount(floor(x/16), floor(z/16)) > 0
			local UW = SpTestBuildOrder(UnitDefNames["staticsonar"].id, x, 0,z, 0) == 0	
			local tex = SlopeType(x, z, TANK, KBOT, METAL, UW, ENVIR)
			local splat = SplatSlopeType(x, z, TANK, KBOT, METAL, UW, ENVIR)
			mapTex[tex][ctTEX[tex]] = {x = x, z = z}
			ctTEX[tex] = ctTEX[tex] + 1
			splatTex[splat][ctsplat[splat]] = {x = x, z = z}
			ctsplat[splat] = ctsplat[splat] + 1
		end
	end
	local cur = Spring.GetTimer()
	Spring.Echo("Map scanned in: "..(Spring.DiffTimers(cur, ago, true)))
end

local function UpdateAllNoSplat()
	local ago = Spring.GetTimer()
	local ENVIR = Spring.GetGameRulesParam("typemap")
	mapTex = {{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{}}
	ctTEX = {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1}
	for x = 0, mapSizeX-1, BLOCK_SIZE do
		for z = 0, mapSizeZ-1, BLOCK_SIZE do
			local TANK = SpTestMoveOrder(UnitDefNames["vehassault"].id, x, 0,z, 0,0,0, true, false, true)
			local KBOT = SpTestMoveOrder(UnitDefNames["cloakriot"].id, x, 0,z, 0,0,0, true, false, true)
			local METAL = SpGetMetalAmount(floor(x/16), floor(z/16)) > 0
			local UW = SpTestBuildOrder(UnitDefNames["staticsonar"].id, x, 0,z, 0) == 0	
			local tex = SlopeType(x, z, TANK, KBOT, METAL, UW, ENVIR)
			mapTex[tex][ctTEX[tex]] = {x = x, z = z}
			ctTEX[tex] = ctTEX[tex] + 1
		end
	end
	local cur = Spring.GetTimer()
	Spring.Echo("Map scanned in: "..(Spring.DiffTimers(cur, ago, true)))
end

local function Shutdown()
	for x = 0, SQUARES_X-1 do
		for z = 0, SQUARES_Z-1 do
			spSetMapSquareTexture(x,z, "")
		end
	end
	activestate = false
end

function SlopeType(x,z,t,k,m,uw,e)
	if uw then
		if m then
			return 16
		elseif t then
			return rand(1,5)
		elseif k then
			return rand(6,10)
		else
			return rand(11,15)
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
			return rand(1,2)
		elseif t then
			if e == "desert" then
				return (rand(1,2) == 2) and (rand(1,2) == 2) and (rand(1,2) == 2) and (rand(1,2) == 2) and 2 or 1
			else
				return (1)
			end
		elseif k then
			if e == "arctic" then
				return rand(1,2)
			elseif e == "temperate" then
				return (rand(1,2) == 1) and (rand(1,2) == 1) and (rand(1,2) == 1) and 1 or 2
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
			return rand(1,2)
		elseif e == "arctic" then
			return (rand(1,2) == 1) and (rand(1,2) == 1) and (rand(1,2) == 1) and 1 or 2
		elseif t then
			return 3
		elseif k then
			return 3
		else
			return 3
		end
	end
end

function gadget:Initialize()
	if (not gl.RenderToTexture) then --super bad graphic driver
		return
	end
	SetTextureSet(Spring.GetGameRulesParam("typemap"))
	if useShadingTextures then
		UpdateAll()
	else
		UpdateAllNoSplat()
	end
	initialized = true
	activestate = true
end

end