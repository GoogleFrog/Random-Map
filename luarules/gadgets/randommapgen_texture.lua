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

local BLOCK_SIZE  = 4
local DRAW_OFFSET = 2 * BLOCK_SIZE/MAP_Z - 1

local VEH_NORMAL      = 0.892
local BOT_NORMAL_PLUS = 0.81
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

local GL_RGBA = 0x1908
local GL_RGBA16F = 0x881A
local GL_RGBA32F = 0x8814

local COLOR_TEX_LIMIT = 6

local floor  = math.floor
local random = math.random

local SPLAT_POOL = {
	{0.55,0.0,0.0,0.7}, --R
	{0.0,0.75,0.0,0.7}, --G
	{0.0,0.0,0.75,0.7}, --B
	{0.0,0.0,0.0,0.7}, --A
}
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

local function SetMapTexture(texturePool, mapTexX, mapTexZ, topTexX, topTexZ, topTexAlpha, splatTexX, splatTexZ, mapHeight)
	local DrawStart = Spring.GetTimer()
	local usedsplat
	local usedgrass
	local usedminimap
	
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
	
	local function DrawLoop()
		local loopCount = 0
		glColor(1, 1, 1, 1)
		local ago = Spring.GetTimer()
		
		glRenderToTexture(topFullTex, function ()
			for i = 1, #texturePool do
				local texX = mapTexX[i]
				local texZ = mapTexZ[i]
				if i == COLOR_TEX_LIMIT then
					glColor(1, 1, 1, 1)
				end
				if texX then
					glTexture(texturePool[i].texture)
					for j = 1, #texX do
						if i < COLOR_TEX_LIMIT then
							local prop = math.max(0, math.min(1, (mapHeight[texX[j]][texZ[j]] - 20)/400))
							glColor(0.6 + 0.4*(1 - prop), 0.65 + 0.3*prop, 0.9 + 0.1*(1 - prop), 0.83 + 0.15*(1 - prop))
						end
						glTexRect(texX[j]*MAP_FAC_X - 1, texZ[j]*MAP_FAC_Z - 1,
							texX[j]*MAP_FAC_X + DRAW_OFFSET, texZ[j]*MAP_FAC_Z + DRAW_OFFSET)
					end
				end
			end
		end)
		Sleep()
		Spring.ClearWatchDogTimer()
		glTexture(false)
		
		local cur = Spring.GetTimer()
		Spring.Echo("FullTex rendered in: "..(Spring.DiffTimers(cur, ago, true)))
		
		local ago = Spring.GetTimer()
		gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
		glRenderToTexture(topFullTex, function ()
			for i = 1, #texturePool do
				local texX = topTexX[i]
				local texZ = topTexZ[i]
				local texAlpha = topTexAlpha[i]
				if texX then
					glTexture(texturePool[i].texture)
					for j = 1, #texX do
						if texAlpha[j] > 0.01 then
							glColor(1, 1, 1, texAlpha[j])
							glTexRect(texX[j]*MAP_FAC_X - 1, texZ[j]*MAP_FAC_Z - 1, texX[j]*MAP_FAC_X + DRAW_OFFSET, texZ[j]*MAP_FAC_Z + DRAW_OFFSET)
						end
					end
				end
			end
		end)
		Sleep()
		Spring.ClearWatchDogTimer()
		glColor(1, 1, 1, 1)
		glTexture(false)
		
		local cur = Spring.GetTimer()
		Spring.Echo("TopTex rendered in: "..(Spring.DiffTimers(cur, ago, true)))
		
		if USE_SHADING_TEXTURE then
			local ago2 = Spring.GetTimer()
			glRenderToTexture(topSplattex, function ()
				for i = 1, #SPLAT_POOL do
					local texX = splatTexX[i]
					local texZ = splatTexZ[i]
					if texX then
						local red, green, blue, alpha = SPLAT_POOL[i][1], SPLAT_POOL[i][2], SPLAT_POOL[i][3], SPLAT_POOL[i][4]
						for j = 1, #texX do
							--if i == 1 then
							--	glColor(0.5 + math.random()*0.5, green + math.random()*0.25, 0.1 + math.random()*0.6, alpha + math.random()*0.3)
							--elseif i == 2 then
							--	glColor(red + math.random()*0.25, 0.4 + math.random()*0.6, blue + math.random()*0.25, alpha + math.random()*0.3)
							--else
								glColor(red + math.random()*0.25, green + math.random()*0.25, blue + math.random()*0.25, alpha + math.random()*0.3)
							--end
							glRect(texX[j]*MAP_FAC_X -1, texZ[j]*MAP_FAC_Z - 1, texX[j]*MAP_FAC_X + DRAW_OFFSET, texZ[j]*MAP_FAC_Z + DRAW_OFFSET)
						end
					end
				end
			end)
			Sleep()
			Spring.ClearWatchDogTimer()
			cur = Spring.GetTimer()
			Spring.Echo("Splattex rendered in: "..(Spring.DiffTimers(cur, ago2, true)))
			glColor(1, 1, 1, 1)
		end

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

		if USE_SHADING_TEXTURE then
			Spring.SetMapShadingTexture("$grass", texOut)
			usedgrass = texOut
			Spring.SetMapShadingTexture("$minimap", texOut)
			usedminimap = texOut
			Spring.Echo("Applied grass and minimap textures")
		end
		gl.DeleteTextureFBO(fulltex)
		
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
		
		mapfullyprocessed = true
	end
	
	StartScript(DrawLoop)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function GetSplatTex(height, vehiclePass, botPass, inWater)
	if inWater then
		if (height < SHALLOW_HEIGHT) or (random() < 0.5) then
			return 3
		end
		return GetSplatTex(height, vehiclePass, botPass, false)
	end
	if vehiclePass then
		return 1
	elseif botPass then
		return ((random() < 0.26) and 2) or 1
	end
	return ((random() < 0.9) and 2) or 1
end

local function GetMainTex(height, vehiclePass, botPass, inWater)
	if inWater then
		if vehiclePass then
			return 17
		end
		if botPass then
			return 18
		end
		return 19
	end
	if vehiclePass then
		return 1 + floor(random()*5)
	end
	if botPass then
		return 6 + floor(random()*5)
	end
	return random(11, 15)
end

local function GetTopTex(normal, height, vehiclePass, botPassPlus, botPass, inWater)
	if inWater and height < SHALLOW_HEIGHT then
		if height < SHALLOW_HEIGHT then
			return
		end
		local prop = math.max(1, math.min(1, (height - SHALLOW_HEIGHT)/80))
		return 16, 0.5 + 0.5*prop
	end
	
	local minNorm, maxNorm, topTex
	if vehiclePass then
		topTex = GetMainTex(height, false, true)
		minNorm, maxNorm = VEH_NORMAL, 1
	elseif botPassPlus then
		topTex = GetMainTex(height, false, true)
		minNorm, maxNorm = BOT_NORMAL_PLUS, VEH_NORMAL
	elseif botPass then
		topTex = GetMainTex(height, false, false)
		minNorm, maxNorm = BOT_NORMAL, BOT_NORMAL_PLUS
	else
		topTex = 16
		minNorm, maxNorm = 0, BOT_NORMAL
	end
	
	local textureProp = (1 - (normal - minNorm)/(maxNorm - minNorm))
	local topAlpha
	if vehiclePass then
		if textureProp > 0.15 then
			topAlpha = 0.075 + 0.875*(textureProp - 0.15) / 0.85
		else
			topAlpha = 0.5*textureProp
		end
	elseif botPassPlus then
		topAlpha = textureProp
	elseif botPass then
		topAlpha = 0.9*textureProp*textureProp
	else
		if textureProp > 0.4 then
			topAlpha = 0.1
		elseif textureProp > 0.2 then
			topAlpha = (textureProp - 0.2)*0.5
		else
			return false
		end
	end
	
	if vehiclePass then
		if textureProp > 0.18 then
			if height%7 > 4.5 then
				local prop = math.max(0, math.min(1, (textureProp - 0.18)/0.3))*0.8 + 0.2
				topAlpha = math.max(0, topAlpha - (0.1 + 0.22*prop))
			end
		end
	elseif botPassPlus then
		local modHeight = height%7
		if modHeight > 6.5 then
			local prop = 1 - (modHeight - 6)*2
			topAlpha = textureProp*(0.1 + 0.2*prop) + (0.9 - 0.2*prop)
		elseif modHeight > 4.5 then
			topAlpha = textureProp*0.3 + 0.7
		elseif modHeight > 4 then
			local prop = (modHeight - 4)*2
			topAlpha = textureProp*(0.1 + 0.2*prop) + (0.9 - 0.2*prop)
		else
			topAlpha = textureProp*0.1 + 0.9
		end
	elseif botPass then
		if height%24 > 17 then
			topAlpha = (1 - topAlpha)*textureProp + (1 - topAlpha)*textureProp
		end
	else
		local modHeight = (height -2 + 4*math.random())%54
		if modHeight > 18 then
			local prop = math.min(1, 1.2*(1 - math.abs(modHeight - 36)/18)*0.05)
			topAlpha = (1 - topAlpha)*prop + (1 - prop)*topAlpha
		else
			return false
		end
	end
	
	return topTex, topAlpha
end

local function GetSlopeTexture(x, z)
	x, z = x + BLOCK_SIZE/2, z + BLOCK_SIZE/2
	
	local normal      = select(2, Spring.GetGroundNormal(x, z, true))
	local height      = Spring.GetGroundHeight(x, z)
	local vehiclePass = (normal > VEH_NORMAL)
	local botPass     = (normal > BOT_NORMAL)
	local botPassPlus = (normal > BOT_NORMAL_PLUS)
	local inWater     = false and (height < 6)
	
	local topTex, topAlpha = GetTopTex(normal, height, vehiclePass, botPassPlus, botPass, inWater)
	local mainTex = GetMainTex(height, botPassPlus, botPass, inWater)
	local splatTex = GetSplatTex(height, vehiclePass, botPass, inWater)
	
	return mainTex, splatTex, topTex, topAlpha, height
end

local function InitializeTextures(useSplat, typemap)
	local ago = Spring.GetTimer()
	local mapTexX, mapTexZ = {}, {}
	local splatTexX, splatTexZ = {}, {}
	local topTexX, topTexZ, topTexAlpha = {}, {}, {}
	
	local mapHeight = {}
	
	for x = 0, MAP_X - 1, BLOCK_SIZE do
		mapHeight[x] = {}
		for z = 0, MAP_Z/2 - 1, BLOCK_SIZE do
			local tex, splat, topTex, topAlpha, height = GetSlopeTexture(x, z)
			
			-- Texture is flipped for the lower half of the map
			mapTexX[tex] = mapTexX[tex] or {}
			mapTexZ[tex] = mapTexZ[tex] or {}
			mapTexX[tex][#mapTexX[tex] + 1] = x
			mapTexZ[tex][#mapTexZ[tex] + 1] = z
			
			mapHeight[x][z] = height
			
			if topTex then
				topTexX[topTex] = topTexX[topTex] or {}
				topTexZ[topTex] = topTexZ[topTex] or {}
				topTexAlpha[topTex] = topTexAlpha[topTex] or {}
				topTexX[topTex][#topTexX[topTex] + 1] = x
				topTexZ[topTex][#topTexZ[topTex] + 1] = z
				topTexAlpha[topTex][#topTexAlpha[topTex] + 1] = topAlpha
			end
			
			if splat and useSplat then
				splatTexX[splat] = splatTexX[splat] or {}
				splatTexZ[splat] = splatTexZ[splat] or {}
				splatTexX[splat][#splatTexX[splat] + 1] = x
				splatTexZ[splat][#splatTexZ[splat] + 1] = z
			end
		end
	end
	local cur = Spring.GetTimer()
	Spring.Echo("Map scanned in: "..(Spring.DiffTimers(cur, ago, true)))
	
	return mapTexX, mapTexZ, topTexX, topTexZ, topTexAlpha, splatTexX, splatTexZ, mapHeight
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function SetupTextureSet(textureSetName)
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
			texture = texturePath.."b5.png",
			size = 92,
			tile = 1,
		},
		[7] = {
			texture = texturePath.."b1.png",
			size = 92,
			tile = 1,
		},
		[8] = {
			texture = texturePath.."b2.png",
			size = 92,
			tile = 1,
		},
		[9] = {
			texture = texturePath.."b3.png",
			size = 92,
			tile = 1,
		},
		[10] = {
			texture = texturePath.."b4.png",
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

local vehTexPool, botTexPool, spiderTexPool, uwTexPool
local mapTexX, mapTexZ, topTexX, topTexZ, topTexAlpha, splatTexX, splatTexZ, mapHeight

function gadget:DrawGenesis()
	if not initialized then
		return
	end
	if mapfullyprocessed then
		gadgetHandler:RemoveGadget()
		return
	end
	
	if activeCoroutine then
		UpdateCoroutines()
	else
		SetMapTexture(texturePool, mapTexX, mapTexZ, topTexX, topTexZ, topTexAlpha, splatTexX, splatTexZ, mapHeight)
	end
end

function gadget:MousePress(x, y, button)
	return (button == 1) and (not mapfullyprocessed)
end

local function MakeMapTexture()
	if (not gl.RenderToTexture) then --super bad graphic driver
		mapfullyprocessed = true
		return
	end
	texturePool = SetupTextureSet(Spring.GetGameRulesParam("typemap"))
	mapTexX, mapTexZ, topTexX, topTexZ, topTexAlpha, splatTexX, splatTexZ, mapHeight = InitializeTextures(USE_SHADING_TEXTURE, Spring.GetGameRulesParam("typemap"))
	initialized = true
end

local updateCount = 0
function gadget:Update(n)
	if not updateCount then
		return
	end
	updateCount = updateCount + 1
	if updateCount > 2 then
		updateCount = false
		MakeMapTexture()
	end
end
