local UNIFORM_TYPE_MIXED        = 0 -- includes arrays; float or int
local UNIFORM_TYPE_INT          = 1 -- includes arrays
local UNIFORM_TYPE_FLOAT        = 2 -- includes arrays
local UNIFORM_TYPE_FLOAT_MATRIX = 3


local function new(class, shaderParams, shaderName, showWarn)
	return setmetatable(
	{
		shaderName = shaderName or "Unnamed Shader",
		shaderParams = shaderParams or {},
		showWarn = showWarn or true,
		shaderObj = nil,
		active = false,
		uniforms = {},
	}, class)
end

local function isGeometryShaderSupported()
	return gl.HasExtension("GL_ARB_geometry_shader4") and (gl.SetShaderParameter ~= nil or gl.SetGeometryShaderParameter ~= nil)
end

local function isTesselationShaderSupported()
	return gl.HasExtension("GL_ARB_tessellation_shader") and (gl.SetTesselationShaderParameter ~= nil)
end


local LuaShader = setmetatable({}, {
	__call = function(self, ...) return new(self, ...) end,
	})
LuaShader.__index = LuaShader
LuaShader.isGeometryShaderSupported = isGeometryShaderSupported()
LuaShader.isTesselationShaderSupported = isTesselationShaderSupported()

-----------------============ General LuaShader methods ============-----------------
function LuaShader:Compile()
	if not gl.CreateShader then
		Spring.Echo(string.format("LuaShader: [%s] shader errors:\n%s", self.shaderName, "GLSL Shaders are not supported by hardware or drivers"))
		return false
	end

	self.shaderObj = gl.CreateShader(self.shaderParams)
	local shaderObj = self.shaderObj

	local shLog = gl.GetShaderLog() or ""

	if not shaderObj then
		Spring.Echo(string.format("LuaShader: [%s] shader errors:\n%s", self.shaderName, shLog))
		return false
	elseif (self.showWarn and shLog ~= "") then
		Spring.Echo(string.format("LuaShader: [%s] shader warnings:\n%s", self.shaderName, shLog))
	end

	local uniforms = self.uniforms
	for idx, info in ipairs(gl.GetActiveUniforms(shaderObj)) do
		local uniName = string.gsub(info.name, "%[0%]", "") -- change array[0] to array
		uniforms[uniName] = {
			location = gl.GetUniformLocation(shaderObj, uniName),
			type = info.type,
			size = info.size,
			values = {},
		}
		--Spring.Echo(uniName, uniforms[uniName].location, uniforms[uniName].type, uniforms[uniName].size)
	end
	return true
end

LuaShader.Initialize = LuaShader.Compile

function LuaShader:GetHandle()
	if self.shaderObj ~= nil then
		return self.shaderObj
	else
		local funcName = (debug and debug.getinfo(1).name) or "UnknownFunction"
		Spring.Echo(string.format("LuaShader: [%s] shader error:\n%s", self.shaderName, string.format("Attempt to use invalid shader object in [%s](). Did you call :Compile() or :Initialize()?", funcName)))
	end
end

function LuaShader:Delete()
	if self.shaderObj ~= nil then
		gl.DeleteShader(self.shaderObj)
	else
		local funcName = (debug and debug.getinfo(1).name) or "UnknownFunction"
		Spring.Echo(string.format("LuaShader: [%s] shader error:\n%s", self.shaderName, string.format("Attempt to use invalid shader object in [%s](). Did you call :Compile() or :Initialize()", funcName)))
	end
end

LuaShader.Finalize = LuaShader.Delete

function LuaShader:Activate()
	if self.shaderObj ~= nil then
		self.active = true
		return gl.UseShader(self.shaderObj)
	else
		local funcName = (debug and debug.getinfo(1).name) or "UnknownFunction"
		Spring.Echo(string.format("LuaShader: [%s] shader error:\n%s", self.shaderName, string.format("Attempt to use invalid shader object in [%s](). Did you call :Compile() or :Initialize()", funcName)))
		return false
	end
end

function LuaShader:ActivateWith(func, ...)
	if self.shaderObj ~= nil then
		self.active = true
		gl.ActiveShader(self.shaderObj, func, ...)
		self.active = false
	else
		local funcName = (debug and debug.getinfo(1).name) or "UnknownFunction"
		Spring.Echo(string.format("LuaShader: [%s] shader error:\n%s", self.shaderName, string.format("Attempt to use invalid shader object in [%s](). Did you call :Compile() or :Initialize()", funcName)))
	end
end

function LuaShader:Deactivate()
	self.active = false
	gl.UseShader(0)
end
-----------------============ End of general LuaShader methods ============-----------------


-----------------============ Friend LuaShader functions ============-----------------
local function getUniform(self, name)
	if not self.active then
		Spring.Echo(string.format("LuaShader: [%s] shader error:\n%s", self.shaderName, string.format("Trying to set uniform [%s] on inactive shader object. Did you use :Activate() or :ActivateWith()?", name)))
		return nil
	end
	local uniform = self.uniforms[name]
	if not uniform then
		if self.showWarn then
			Spring.Echo(string.format("LuaShader: [%s] shader warning:\n%s", self.shaderName, string.format("Attempt to set uniform [%s], which does not exist in the compiled shader", name)))
		end
		return nil
	end
	return uniform
end

local function isUpdateRequired(uniform, tbl)
	if (#tbl == 1) and (type(tbl[1]) == "string") then --named matrix
		return true --no need to update cache
	end

	local update = false
	local cachedValues = uniform.values
	for i, val in ipairs(tbl) do
		if cachedValues[i] ~= val then
			cachedValues[i] = val --update cache
			update = true
		end
	end

	return update
end
-----------------============ End of friend LuaShader functions ============-----------------


-----------------============ LuaShader uniform manipulation functions ============-----------------
-- TODO: do it safely with types, len, size check

--FLOAT UNIFORMS
local function setUniformAlwaysImpl(uniform, ...)
	gl.Uniform(uniform.location, ...)
	return true --currently there is no way to check if uniform is set or not :(
end

function LuaShader:SetUniformAlways(name, ...)
	local uniform = getUniform(self, name)
	if not uniform then
		return false
	end
	return setUniformAlwaysImpl(uniform, ...)
end

local function setUniformImpl(uniform, ...)
	if isUpdateRequired(uniform, {...}) then
		return setUniformAlwaysImpl(uniform, ...)
	end
	return true
end

function LuaShader:SetUniform(name, ...)
	local uniform = getUniform(self, name)
	if not uniform then
		return false
	end
	return setUniformImpl(uniform, ...)
end

LuaShader.SetUniformFloat = LuaShader.SetUniform
LuaShader.SetUniformFloatAlways = LuaShader.SetUniformAlways


--INTEGER UNIFORMS
local function setUniformIntAlwaysImpl(uniform, ...)
	gl.UniformInt(uniform.location, ...)
	return true --currently there is no way to check if uniform is set or not :(
end

function LuaShader:SetUniformIntAlways(name, ...)
	local uniform = getUniform(self, name)
	if not uniform then
		return false
	end
	return setUniformIntAlwaysImpl(uniform, ...)
end

local function setUniformIntImpl(uniform, ...)
	if isUpdateRequired(uniform, {...}) then
		return setUniformIntAlwaysImpl(uniform, ...)
	end
	return true
end

function LuaShader:SetUniformInt(name, ...)
	local uniform = getUniform(self, name)
	if not uniform then
		return false
	end
	return setUniformIntImpl(uniform, ...)
end


--FLOAT ARRAY UNIFORMS
local function setUniformFloatArrayAlwaysImpl(uniform, tbl)
	gl.UniformArray(uniform.location, UNIFORM_TYPE_FLOAT, tbl)
	return true --currently there is no way to check if uniform is set or not :(
end

function LuaShader:SetUniformFloatArrayAlways(name, tbl)
	local uniform = getUniform(self, name)
	if not uniform then
		return false
	end
	return setUniformFloatArrayAlwaysImpl(uniform, tbl)
end

local function setUniformFloatArrayImpl(uniform, tbl)
	if isUpdateRequired(uniform, tbl) then
		return setUniformFloatArrayAlwaysImpl(uniform, tbl)
	end
	return true
end

function LuaShader:SetUniformFloatArray(name, tbl)
	local uniform = getUniform(self, name)
	if not uniform then
		return false
	end
	return setUniformFloatArrayImpl(uniform, tbl)
end


--INT ARRAY UNIFORMS
local function setUniformIntArrayAlwaysImpl(uniform, tbl)
	gl.UniformArray(uniform.location, UNIFORM_TYPE_INT, tbl)
	return true --currently there is no way to check if uniform is set or not :(
end

function LuaShader:SetUniformIntArrayAlways(name, tbl)
	local uniform = getUniform(self, name)
	if not uniform then
		return false
	end
	return setUniformIntArrayAlwaysImpl(uniform, tbl)
end

local function setUniformIntArrayImpl(uniform, tbl)
	if isUpdateRequired(uniform, tbl) then
		return setUniformIntArrayAlwaysImpl(uniform, tbl)
	end
	return true
end

function LuaShader:SetUniformIntArray(name, tbl)
	local uniform = getUniform(self, name)
	if not uniform then
		return false
	end
	return setUniformIntArrayImpl(uniform, tbl)
end


--MATRIX UNIFORMS
local function setUniformMatrixAlwaysImpl(uniform, tbl)
	gl.UniformMatrix(uniform.location, unpack(tbl))
	return true --currently there is no way to check if uniform is set or not :(
end

function LuaShader:SetUniformMatrixAlways(name, ...)
	local uniform = getUniform(self, name)
	if not uniform then
		return false
	end
	return setUniformMatrixAlwaysImpl(uniform, {...})
end

local function setUniformMatrixImpl(uniform, tbl)
	if isUpdateRequired(uniform, tbl) then
		return setUniformMatrixAlwaysImpl(uniform, tbl)
	end
	return true
end

function LuaShader:SetUniformMatrix(name, ...)
	local uniform = getUniform(self, name)
	if not uniform then
		return false
	end
	return setUniformMatrixImpl(uniform, {...})
end
-----------------============ End of LuaShader uniform manipulation functions ============-----------------

return LuaShader