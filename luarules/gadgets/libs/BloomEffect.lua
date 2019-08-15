local GaussianBlur = VFS.Include("LuaRules/gadgets/libs/GaussianBlur.lua")
local LuaShader = VFS.Include("LuaRules/gadgets/libs/LuaShader.lua")

local GL_RGBA = 0x1908

local cutOffFragTemplate = [[
	#version 150 compatibility
	#line 8

	uniform sampler2D texIn;

####CutOffUniforms####

####DoCutOff_Definition####
	#line 1015
	void main(void)
	{
		vec4 texel = texelFetch(texIn, ivec2(gl_FragCoord.xy), 0);
		gl_FragColor = DoCutOff(texel);
	}
]]

local combFragTemplate = [[
	#version 150 compatibility
	#line 2025

	uniform sampler2D texIn;
	uniform sampler2D gaussIn[###NUM_GAUSS###];

	uniform vec2 texOutSize;

####CombUniforms####

####DoCombine_Definition####

####DoToneMapping_Definition####
	#line 3037
	void main(void)
	{
		vec2 uv = gl_FragCoord.xy / texOutSize;

		vec4 colorTexIn = texture(texIn, uv);

		vec4 colorGauss = vec4(0.0);
		for (int i = 0; i < ###NUM_GAUSS###; ++i) {
			colorGauss += texture(gaussIn[i], uv);
		}

		vec4 color = DoCombine(colorTexIn, colorGauss);

		gl_FragColor = DoToneMapping(color);
	}
]]

local doCombineFuncDefault = {
[false] =
[[
	vec4 DoCombine(in vec4 colorTexIn, in vec4 colorGauss) {
		return colorTexIn + colorGauss;
	}
]],
[true] =
[[
	vec4 DoCombine(in vec4 colorTexIn, in vec4 colorGauss) {
		return colorGauss;
	}
]]}

local function new(class, inputs)
	local bloomOnly = ((inputs.bloomOnly == nil and true) or inputs.bloomOnly)
	return setmetatable(
	{
		texIn = inputs.texIn,
		texOut = inputs.texOut,

		unusedTexId = inputs.unusedTexId or 15, -- 15th is unlikely used

		gParams = inputs.gParams, --must have unusedTexId's other than inputs.unusedTexId!!!

		cutOffTexFormat = inputs.cutOffTexFormat or GL_RGBA,

		-- GLSL definition of DoCutOff(in vec4) function
		doCutOffFunc = inputs.doCutOffFunc,
		-- GLSL definition of CutOff Shader Uniforms
		cutOffUniforms = inputs.cutOffUniforms or "",

		-- GLSL definition of DoCombine(in vec4 colorTexIn, in vec4 colorGauss) function
		doCombineFunc = inputs.doCombineFunc or doCombineFuncDefault[bloomOnly],
		-- GLSL definition of DoToneMapping(in vec4 hdrColor) function
		doToneMappingFunc = inputs.doToneMappingFunc,
		-- GLSL definition of Combination Shader Uniforms
		combUniforms = inputs.combUniforms or "",

		bloomOnly = bloomOnly,

		cutOffTex = nil,
		cutOffFBO = nil,

		cutOffShader = nil,
		combShader = nil,

		gbs = {},
		gbTexOut = {},
		outFBO = nil,

		inTexSizeX = 0,
		inTexSizeY = 0,

	}, class)
end

local BloomEffect = setmetatable({}, {
	__call = function(self, ...) return new(self, ...) end,
	})
BloomEffect.__index = BloomEffect

local GL_COLOR_ATTACHMENT0_EXT = 0x8CE0

function BloomEffect:Initialize()
	local texInInfo = gl.TextureInfo(self.texIn)

	self.inTexSizeX, self.inTexSizeY = texInInfo.xsize, texInInfo.ysize

	self.cutOffTex = gl.CreateTexture(texInInfo.xsize, texInInfo.ysize, {
		format = self.cutOffTexFormat,
		border = false,
		min_filter = GL.LINEAR,
		mag_filter = GL.LINEAR,
		wrap_s = GL.CLAMP_TO_EDGE,
		wrap_t = GL.CLAMP_TO_EDGE,
		--fbo = true,
	})

	local gbUnusedTextures = {}

	for i, gParam in ipairs(self.gParams) do
		self.gbTexOut[i] = gl.CreateTexture(texInInfo.xsize, texInInfo.ysize, {
			format = gParam.blurTexIntFormat,
			border = false,
			min_filter = GL.LINEAR,
			mag_filter = GL.LINEAR,
			wrap_s = GL.CLAMP_TO_EDGE,
			wrap_t = GL.CLAMP_TO_EDGE,
			--fbo = true,
		})

		gParam.texIn = self.cutOffTex
		gParam.texOut = self.gbTexOut[i]

		self.gbs[i] = GaussianBlur(gParam)
		self.gbs[i]:Initialize()

		gbUnusedTextures[i] = self.gbs[i].unusedTexId
	end

	self.cutOffFBO = gl.CreateFBO({
		color0 = self.cutOffTex,
		drawbuffers = {GL_COLOR_ATTACHMENT0_EXT},
	})

	self.outFBO = gl.CreateFBO({
		color0 = self.texOut,
		drawbuffers = {GL_COLOR_ATTACHMENT0_EXT},
	})

	local cutOffShaderFrag
		cutOffShaderFrag = string.gsub(cutOffFragTemplate, "####DoCutOff_Definition####", self.doCutOffFunc)
		cutOffShaderFrag = string.gsub(cutOffShaderFrag, "####CutOffUniforms####", self.cutOffUniforms)

	self.cutOffShader = LuaShader({
		fragment = cutOffShaderFrag,
		uniformInt = {
			texIn = self.unusedTexId,
		},
	}, "BloomEffect: Cutoff Shader")
	self.cutOffShader:Initialize()


	local texOutInfo = gl.TextureInfo(self.texOut)

	local combShaderFrag
		combShaderFrag = string.gsub(combFragTemplate, "####DoCombine_Definition####", self.doCombineFunc)
		combShaderFrag = string.gsub(combShaderFrag, "####DoToneMapping_Definition####", self.doToneMappingFunc)
		combShaderFrag = string.gsub(combShaderFrag, "####CombUniforms####", self.combUniforms)
		combShaderFrag = string.gsub(combShaderFrag, "###NUM_GAUSS###", #self.gParams)

	self.combShader = LuaShader({
		fragment = combShaderFrag,
		uniformInt = {
			texIn = self.unusedTexId,
		},
		uniformFloat ={
			texOutSize = {texOutInfo.xsize, texOutInfo.ysize}
		},
	}, "BloomEffect: Combination Shader")
	self.combShader:Initialize()

	self.combShader:ActivateWith( function ()
		self.combShader:SetUniformIntArrayAlways("gaussIn", gbUnusedTextures)
	end)
end

function BloomEffect:GetShaders()
	return self.cutOffShader, self.combShader
end

function BloomEffect:Execute(isScreenSpace)
	gl.Texture(self.unusedTexId, self.texIn)

	self.cutOffShader:ActivateWith( function ()
		gl.ActiveFBO(self.cutOffFBO, function()
			gl.DepthTest(false)
			gl.Blending(false)
			if isScreenSpace then
				gl.TexRect(0, 0, self.inTexSizeX, self.inTexSizeY)
			else
				gl.TexRect(-1, -1, 1, 1)
			end
		end)
	end)

	gl.Texture(self.unusedTexId, self.cutOffTex)

	for i, gb in ipairs(self.gbs) do
		gb:Execute(isScreenSpace)
	end

	if not self.bloomOnly then
		gl.Texture(self.unusedTexId, self.texIn)
	end

	for i, gb in ipairs(self.gbs) do
		gl.Texture(gb.unusedTexId, gb.texOut)
	end

	self.combShader:ActivateWith( function ()
		gl.ActiveFBO(self.outFBO, function()
			gl.DepthTest(false)
			gl.Blending(false)
			if isScreenSpace then
				gl.TexRect(0, 0, self.inTexSizeX, self.inTexSizeY)
			else
				gl.TexRect(-1, -1, 1, 1)
			end
		end)
	end)

	for i, gb in ipairs(self.gbs) do
		gl.Texture(gb.unusedTexId, false)
	end

	gl.Texture(self.unusedTexId, false)
end

function BloomEffect:Finalize()
	for i, gb in ipairs(self.gbs) do
		gl.DeleteTexture(self.gbTexOut[i])
		gb:Finalize()
	end

	gl.DeleteTexture(self.cutOffTex)

	gl.DeleteFBO(self.cutOffFBO)
	gl.DeleteFBO(self.outFBO)

	self.cutOffShader:Finalize()
	self.combShader:Finalize()
end

return BloomEffect
