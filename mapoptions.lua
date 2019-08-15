----------------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------
-- File:        MapOptions.lua
-- Description: Custom MapOptions file that makes possible to set up variable options before game starts, like ModOptions.lua
-- Author:      SirArtturi, Lurker, Smoth, jK
----------------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------
--	NOTES:
--	- using an enumerated table lets you specify the options order
--
--	These keywords must be lowercase for LuaParser to read them.
--
--	key:			the string used in the script.txt
--	name:		 the displayed name
--	desc:		 the description (could be used as a tooltip)
--	type:		 the option type
--	def:			the default value
--	min:			minimum value for number options
--	max:			maximum value for number options
--	step:		 quantization step, aligned to the def value
--	maxlen:	 the maximum string length for string options
--	items:		array of item strings for list options
--	scope:		'all', 'player', 'team', 'allyteam'			<<< not supported yet >>>
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local options = {
--// Options
	--// Atmosphere
	{
		key  = "seed",
		name = "Random Seed",
		desc = "Controls which map will be generated",
		type = "number",
		def  = 0,
		min = 0,
		max = 10000,
	},
	{
		key  = "symtype",
		name = "Symmetry",
		desc = "0 = Random, 1 = Central, 2 = Vertical, 3 = Horizontal, 4 = diagonal top-left, 5 = diagonal top-right, 6 = no symmetry",
		type = "number",
		def  = 0,
		min = 0,
		max = 6,
	},
	
}

return options