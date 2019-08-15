local LuaShader = VFS.Include("LuaRules/gadgets/libs/LuaShader.lua")

local GL_RGBA = 0x1908

local function new(class, inputs)
	return setmetatable(
	{
		texIn = inputs.texIn,
		texOut = inputs.texOut,
		unusedTexId = inputs.unusedTexId or 16, -- 16th is unlikely used
		downScale = inputs.downScale or 1.0,
		linearSampling = inputs.linearSampling or true,
		sigma = inputs.sigma or 1.0,
		halfKernelSize = inputs.halfKernelSize or 5,
		valMult = inputs.valMult or 1.0,
		repeats = inputs.repeats or 1,
		blurTexIntFormat = inputs.blurTexIntFormat or GL_RGBA,

		blurTex = {},
		blurBFO = {},
		blurShader = {},

		inTexSizeX = 0,
		inTexSizeY = 0,

		blurTexSizeX = 0,
		blurTexSizeY = 0,

		texOutSizeX = 0,
		texOutSizeY = 0,

		weights = nil,
		offsets = nil,

		outFBO = nil,
	}, class)
end

local GaussianBlur = setmetatable({}, {
	__call = function(self, ...) return new(self, ...) end,
	})
GaussianBlur.__index = GaussianBlur

local function G(x, sigma)
	return ( 1 / ( math.sqrt(2 * math.pi) * sigma ) ) * math.exp( -(x * x) / (2 * sigma * sigma) )
end

local function getGaussDiscreteWeightsOffsets(sigma, kernelHalfSize, valMult)
	local weights = {}
	local offsets = {}

	weights[1] = G(0, sigma)
	local sum = weights[1]

	for i = 1, kernelHalfSize - 1 do
		weights[i + 1] = G(i, sigma)
		sum = sum + 2.0 * weights[i + 1]
	end

	for i = 0, kernelHalfSize - 1 do --normalize so the weights sum up to valMult
		weights[i + 1] = weights[i + 1] / sum * valMult
		offsets[i + 1] = i
	end
	return weights, offsets
end

--see http://rastergrid.com/blog/2010/09/efficient-gaussian-blur-with-linear-sampling/
local function getGaussLinearWeightsOffsets(sigma, kernelHalfSize, valMult)
	local dWeights, dOffsets = getGaussDiscreteWeightsOffsets(sigma, kernelHalfSize, 1.0)

	local weights = {dWeights[1]}
	local offsets = {dOffsets[1]}

	for i = 1, (kernelHalfSize - 1) / 2 do
		local newWeight = dWeights[2 * i] + dWeights[2 * i + 1]
		weights[i + 1] = newWeight * valMult
		offsets[i + 1] = (dOffsets[2 * i] * dWeights[2 * i] + dOffsets[2 * i + 1] * dWeights[2 * i + 1]) / newWeight
	end
	return weights, offsets
end

local gaussFragTemplate = [[
	uniform sampler2D tex;
	uniform float offsets[###NUM###];
	uniform float weights[###NUM###];
	uniform vec2 dir;

	uniform vec2 outSize;

	void main(void)
	{
		vec2 uv = gl_FragCoord.xy / outSize;
		vec4 acc = texture( tex, uv ) * weights[0];

		for (int i = 1; i < ###NUM###; ++i) {
			vec2 uvP = (gl_FragCoord.xy + offsets[i] * dir) / outSize;
			vec2 uvN = (gl_FragCoord.xy - offsets[i] * dir) / outSize;

			bvec4 okCoords;

			okCoords = bvec4(uvP.x >= 0.0, uvP.x <= 1.0, uvP.y >= 0.0, uvP.y <= 1.0);
			if (all(okCoords))
				acc += texture( tex, uvP ) * weights[i];

			okCoords = bvec4(uvN.x >= 0.0, uvN.x <= 1.0, uvN.y >= 0.0, uvN.y <= 1.0);
			if (all(okCoords))
				acc += texture( tex, uvN ) * weights[i];
		}
		gl_FragColor = acc;
	}
]]

local GL_COLOR_ATTACHMENT0_EXT = 0x8CE0

function GaussianBlur:Initialize()
	local texInInfo = gl.TextureInfo(self.texIn)

	self.inTexSizeX, self.inTexSizeY = texInInfo.xsize , texInInfo.ysize
	self.blurTexSizeX, self.blurTexSizeY = math.floor(texInInfo.xsize / self.downScale), math.floor(texInInfo.ysize / self.downScale)

	local texOutInfo = gl.TextureInfo(self.texOut)
	self.texOutSizeX, self.texOutSizeY = texOutInfo.xsize, texOutInfo.ysize

	for i = 1, 2 do
		self.blurTex[i] = gl.CreateTexture(self.blurTexSizeX, self.blurTexSizeY, {
			format = self.blurTexIntFormat,
			border = false,
			min_filter = (self.linearSampling and GL.LINEAR) or GL.NEAREST,
			mag_filter = (self.linearSampling and GL.LINEAR) or GL.NEAREST,
			wrap_s = GL.CLAMP_TO_EDGE,
			wrap_t = GL.CLAMP_TO_EDGE,
			--fbo = true,
		})
	end

	for i = 1, 2 do
		self.blurBFO[i] = gl.CreateFBO({
			color0 = self.blurTex[i],
			drawbuffers = {GL_COLOR_ATTACHMENT0_EXT},
		})
	end

	local halfKernelSizeSafe = math.floor(self.halfKernelSize)
	if halfKernelSizeSafe % 2 == 0 then
		halfKernelSizeSafe = halfKernelSizeSafe + 1
	end

	local fragCode
	if self.linearSampling then
		fragCode = string.gsub(gaussFragTemplate, "###NUM###", tostring(math.floor((halfKernelSizeSafe - 1)/2 + 1)))
		self.weights, self.offsets = getGaussLinearWeightsOffsets(self.sigma, halfKernelSizeSafe, self.valMult)
	else
		fragCode = string.gsub(gaussFragTemplate, "###NUM###", tostring(halfKernelSizeSafe))
		self.weights, self.offsets = getGaussDiscreteWeightsOffsets(self.sigma, halfKernelSizeSafe, self.valMult)
	end

	for i = 1, 2 do
		self.blurShader[i] = LuaShader({
			definitions = {
				"#version 150 compatibility\n",
			},
			fragment = fragCode,
			uniformFloat = {
				dir = {i % 2, (i + 1) % 2},
				outSize = {self.blurTexSizeX, self.blurTexSizeY},
			},
			uniformInt = {
				tex = self.unusedTexId,
			},

		}, string.format("blurShader[%i]", i))
		self.blurShader[i]:Initialize()
		--workaround to non-working array uniforms in gl.CreateShader
		self.blurShader[i]:ActivateWith(function ()
			self.blurShader[i]:SetUniformFloatArray("weights", self.weights)
			self.blurShader[i]:SetUniformFloatArray("offsets", self.offsets)
		end)
	end
	self.outFBO = gl.CreateFBO({
		color0 = self.texOut,
		drawbuffers = {GL_COLOR_ATTACHMENT0_EXT},
	})
end

function GaussianBlur:Execute(isScreenSpace)
	gl.Texture(self.unusedTexId, self.texIn)

	for i = 1, self.repeats do
		self.blurShader[1]:ActivateWith( function ()
			gl.ActiveFBO(self.blurBFO[1], function()
				gl.DepthTest(false)
				gl.Blending(false)
				if isScreenSpace then
					gl.TexRect(0, 0, self.inTexSizeX, self.inTexSizeY)
				else
					gl.TexRect(-1, -1, 1, 1)
				end
			end)
		end)

		gl.Texture(self.unusedTexId, self.blurTex[1])

		self.blurShader[2]:ActivateWith( function ()
			gl.ActiveFBO(self.blurBFO[2], function()
				gl.DepthTest(false)
				gl.Blending(false)
				if isScreenSpace then
					gl.TexRect(0, 0, self.inTexSizeX, self.inTexSizeY)
				else
					gl.TexRect(-1, -1, 1, 1)
				end
			end)
		end)

		gl.Texture(self.unusedTexId, self.blurTex[2])
	end

	gl.Texture(self.unusedTexId, false)

	gl.BlitFBO(	self.blurBFO[2], 0, 0, self.blurTexSizeX, self.blurTexSizeY,
				self.outFBO, 0, 0, self.texOutSizeX, self.texOutSizeY,
				GL.COLOR_BUFFER_BIT, GL.LINEAR )
end

function GaussianBlur:Finalize()
	for i = 1, 2 do
		gl.DeleteTexture(self.blurTex[i])
	end

	for i = 1, 2 do
		gl.DeleteFBO(self.blurBFO[i])
	end

	gl.DeleteFBO(self.outFBO)

	for i = 1, 2 do
		self.blurShader[i]:Finalize()
	end
end


return GaussianBlur
