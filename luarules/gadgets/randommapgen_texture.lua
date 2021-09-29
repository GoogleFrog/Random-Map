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
				if texX then
					glTexture(texturePool[i].texture)
					for j = 1, #texX do
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
			gl.Blending(GL.ONE, GL.ZERO)
			glRenderToTexture(topSplattex, function ()
				for i = 1, #splatTexX do
					glColor(splatTexCol[i])
					glRect(splatTexX[i]*MAP_FAC_X -1, splatTexZ[i]*MAP_FAC_Z - 1, splatTexX[i]*MAP_FAC_X + DRAW_OFFSET, splatTexZ[i]*MAP_FAC_Z + DRAW_OFFSET)
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
		
		if USE_SHADING_TEXTURE then
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

local function GetNormalProp(normal, vehiclePass, botPass, botPassPlus)
	local minNorm, maxNorm, topTex
	if vehiclePass then
		minNorm, maxNorm = VEH_NORMAL, 1
	elseif botPassPlus then
		minNorm, maxNorm = BOT_NORMAL_PLUS, VEH_NORMAL
	elseif botPass then
		minNorm, maxNorm = BOT_NORMAL, BOT_NORMAL_PLUS
	else
		minNorm, maxNorm = 0, BOT_NORMAL
	end
	
	local textureProp = (1 - (normal - minNorm)/(maxNorm - minNorm))
	return textureProp
end

local function GetSplatCol(height, normal)
	local vehiclePass = (normal > VEH_NORMAL)
	local botPassPlus = (normal > BOT_NORMAL_PLUS)
	local botPass     = (normal > BOT_NORMAL)
	local inWater     = (height < 6)
	local textureProp = GetNormalProp(normal, vehiclePass, botPass, botPassPlus)
	
	local grass, hill, cliff, sand = 0.02*math.random(), 0.02*math.random(), 0.02*math.random(), 0.02*math.random()

	local compareHeight = 80 + 20*math.random()
	if height < compareHeight then
		sand = sand + (compareHeight - height)/(30 + math.random()*30)
	end
	
	if vehiclePass then
		local minHeight = 50
		local maxHeight = VEH_HEIGHT_MAX + 45
		local range = 20 - 30*math.random()
		local prop = 0
		
		-- Draw a lot of grass in the right range
		if height < maxHeight then
			if height > maxHeight - range then
				prop = 1 - (height - (maxHeight - range))/range
			elseif height > minHeight + range then
				prop = 1
			elseif height > minHeight then
				prop = (height - minHeight)/range
			end
			grass = grass + 0.1*math.random() + (0.6 + 0.28*math.random())*prop
		end
		
		-- Sand and rocks on mountains, why not
		if height > maxHeight - range - 20 then
			if height < maxHeight then
				prop = (height - (maxHeight - range - 20))/range
			else
				prop = 1
			end
			hill = hill + 0.1*math.random() + (0.3 + 0.6*math.random())*prop
			sand = sand + 0.1*math.random() + (0.1 + 0.1*math.random())*prop
		end
		
		-- Make slopes slightly rocky
		if textureProp > 0.18 then
			hill = hill + (0.5 + 0.2*math.random())*(textureProp - 0.18)
		end
	elseif botPassPlus then
		-- Make slopes slightly grassy
		if textureProp < 0.8 then
			grass = grass + (0.5 + 0.2*math.random())*(0.8 - textureProp)
		end
		
		hill = hill + 0.85 + 0.5*math.random()*textureProp
		
	elseif botPass then
		hill = hill + 0.9 + 0.2*math.random()
		
		-- Make hills slightly cliffy
		if textureProp > 0.5 then
			cliff = cliff + (0.5 + 0.2*math.random())*(textureProp - 0.5)*2
		end
	else
		-- Make cliffs slightly hilly
		if textureProp < 0.5 then
			hill = hill + (0.2 + 0.4*math.random())*(0.5 - textureProp)*2
		end
		
		cliff = cliff + 0.9 + 0.5*math.random()*textureProp
	end
	
	return {math.min(1, grass), math.min(1, hill), math.min(1, sand), math.min(1, cliff)}
end

local function GetMainTex(height, vehiclePass, botPass, inWater)
	if vehiclePass then
		local prop = math.max(0, math.min(1, (height + VEH_HEIGHT_MIN)/(VEH_HEIGHT_MAX - VEH_HEIGHT_MIN)))
		return BLACK_TEX + SPIDER_TEX + BOT_TEX + 1 + floor(prop*(VEH_TEX - VEH_SAMPLE_RANGE) + random()*VEH_SAMPLE_RANGE)
	end
	if botPass then
		return BLACK_TEX + SPIDER_TEX + 1 + floor(random()*BOT_TEX)
	end
	return BLACK_TEX + 1 + floor(random()*SPIDER_TEX)
end

local function GetTopTex(normal, height, vehiclePass, botPassPlus, botPass)
	local topTex, topAlpha
	if vehiclePass then
		topTex = GetMainTex(height, false, true)
	elseif botPassPlus then
		topTex = GetMainTex(height, false, true)
	elseif botPass then
		topTex = GetMainTex(height, false, false)
	else
		topTex = BLACK_TEX
	end
	
	local textureProp = GetNormalProp(normal, vehiclePass, botPass, botPassPlus)
	
	if vehiclePass then
		if textureProp > 0.15 then
			topAlpha = 0.075 + 0.875*(textureProp - 0.15) / 0.85
		else
			topAlpha = 0.5*textureProp
		end
	elseif botPassPlus then
		topAlpha = textureProp*1.5
	elseif botPass then
		topAlpha = math.max(0, 2.1*(textureProp - 0.6))
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
			local modHeight = height%7
			local smoothProp = false
			if modHeight > 6 then
				smoothProp = 1 - (modHeight - 6)
			elseif modHeight > 5 then
				smoothProp = 1
			elseif modHeight > 4 then
				smoothProp = (modHeight - 4)
			end
			if smoothProp then
				local prop = (math.max(0, math.min(1, (textureProp - 0.18)/0.3))*0.8 + 0.2)*smoothProp
				topAlpha = math.max(0, topAlpha - (0.1 + 0.22*prop))
			end
		end
	elseif botPassPlus then
		local modHeight = height%7
		local smoothProp = false
		if modHeight > 6.5 then
			smoothProp = 1 - (modHeight - 6)*2
		elseif modHeight > 4.5 then
			smoothProp = 1
		elseif modHeight > 4 then
			smoothProp = (modHeight - 4)*2
		else
			topAlpha = textureProp*0.25 + 0.9
		end
		if smoothProp then
			topAlpha = textureProp*(0.25 + 0.2*smoothProp) + (0.9 - 0.2*smoothProp)
		end
		topAlpha = math.min(1, topAlpha)
	elseif botPass then
		if height%24 > 23 - 9*textureProp then
			local prop = math.max(0, 1.2*(textureProp - 0.1))
			topAlpha = (1 - topAlpha)*prop + (1 - topAlpha)*prop
			topAlpha = math.min(1, topAlpha)
		end
	else
		local modHeight = height%54
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
	local botPassPlus = (normal > BOT_NORMAL_PLUS)
	local botPass     = (normal > BOT_NORMAL)
	local inWater     = (height < 6)
	
	local topTex, topAlpha = GetTopTex(normal, height, vehiclePass, botPassPlus, botPass)
	local mainTex = GetMainTex(height, botPassPlus, botPass)
	local splatCol = GetSplatCol(height, normal, vehiclePass, botPassPlus, botPass, inWater)
	
	return mainTex, splatCol, topTex, topAlpha, height
end

local function InitializeTextures(useSplat, typemap)
	local ago = Spring.GetTimer()
	local mapTexX, mapTexZ = {}, {}
	local splatTexX, splatTexZ, splatTexCol = {}, {}, {}
	local topTexX, topTexZ, topTexAlpha = {}, {}, {}
	
	local mapHeight = {}
	
	for x = 0, MAP_X - 1, BLOCK_SIZE do
		mapHeight[x] = {}
		for z = 0, MAP_Z/2 - 1, BLOCK_SIZE do
			local tex, splatCol, topTex, topAlpha, height = GetSlopeTexture(x, z)
			
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
			
			if splatCol and useSplat then
				splatTexX[#splatTexX + 1] = x
				splatTexZ[#splatTexZ + 1] = z
				splatTexCol[#splatTexCol + 1] = splatCol
			end
		end
	end
	local cur = Spring.GetTimer()
	Spring.Echo("Map scanned in: "..(Spring.DiffTimers(cur, ago, true)))
	
	return mapTexX, mapTexZ, topTexX, topTexZ, topTexAlpha, splatTexX, splatTexZ, splatTexCol, mapHeight
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
		SetMapTexture(texturePool, mapTexX, mapTexZ, topTexX, topTexZ, topTexAlpha, splatTexX, splatTexZ, splatTexCol, mapHeight)
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
	mapTexX, mapTexZ, topTexX, topTexZ, topTexAlpha, splatTexX, splatTexZ, splatTexCol, mapHeight = InitializeTextures(USE_SHADING_TEXTURE, Spring.GetGameRulesParam("typemap"))
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
