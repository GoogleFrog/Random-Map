local generalWaveMod = 1
local allParams = {
	generalWaveMod = generalWaveMod,
	multParams = {
		scaleMin = 0.65,
		scaleMax = 0.8,
		periodMin = 2000,
		periodMax = 5000 - 1500*generalWaveMod,
		spreadMin = 200,
		spreadMax = 900,
		offsetMin = -0.2,
		offsetMax = 0.2,
		growthMin = 0.15,
		growthMax = 0.2 + 0.2*generalWaveMod,
		wavePeriodMin = 1000,
		wavePeriodMax = 2600,
		waveRotationsMin = 1,
		waveRotationsMax = 8,
		spreadScaleMin = 0.2,
		spreadScaleMax = 0.4,
	},
	
	translateParams = {
		scaleMin = 60,
		scaleMax = 60 + 20*generalWaveMod,
		periodMin = 1800,
		periodMax = 3000,
		spreadMin = 20,
		spreadMax = 120,
		offsetMin = 30,
		offsetMax = 90,
		growthMin = 5,
		growthMax = 20,
		wavePeriodMin = 800,
		wavePeriodMax = 1700,
		waveRotationsMin = 1,
		waveRotationsMax = 8,
		spreadScaleMin = 0.025,
		spreadScaleMax = 0.07,
	},
	
	rotParams = {
		scaleMin = 60,
		scaleMax = 60 + 20*generalWaveMod,
		periodMin = 1800,
		periodMax = 4000,
		spreadMin = 60,
		spreadMax = 300,
		offsetMin = 30,
		offsetMax = 90,
		growthMin = 5,
		growthMax = 20,
		wavePeriodMin = 800,
		wavePeriodMax = 1700,
		waveRotationsMin = 1,
		waveRotationsMax = 8,
	},

	bigMultParams = {
		scaleMin = 0.9,
		scaleMax = 1 + 0.2*generalWaveMod,
		periodMin = 18000,
		periodMax = 45000,
		spreadMin = 2000,
		spreadMax = 8000,
		offsetMin = 0.3,
		offsetMax = 0.4,
		growthMin = 0.02,
		growthMax = 0.2,
		wavePeriodMin = 3500,
		wavePeriodMax = 5000,
		waveRotationsMin = 1,
		waveRotationsMax = 8,
	},
	spaceParams = {
	vorPoints = 2,
	vorPointsRand = 5,
	vorSizePointMult = 0,
	vorSizePointMultRand = 0,
	vorScaleAdjustPoint = 1.3,
	vorScaleAdjustRand = 0.05,
	-- These parameters are affected by vorScaleAdjustPoint and vorScaleAdjustRand
	midPoints = 1,
	midPointRadius = 900,
	midPointSpace = 400,
	minSpace = 230,
	maxSpace = 560,
	pointSplitRadius = 660,
	edgeBias = 1.25,
	------------
	-- IGLOOS --
	------------
	longIglooFlatten = 5,
	iglooTierDiffOpenThreshold = 300,
	openEdgeIglooThreshold = 800,
	iglooHeightMult = 0.55,
	iglooBoostThreshold = 1.3,
	iglooLengthMult = 3,
	iglooMaxHeightBase = 150,
	iglooMaxHeightTierDiffMult = 60,
	iglooMaxHeightVar = 0.2,
	highDiffParallelIglooChance = 1,
	flatIglooChances = {[-1] = 0.95},
	flatIglooWidthMult = {[-1] = 0.4},
	----------------------
	-- RAMPS AND CLIFFS --
	----------------------
	rampWidth = 500,
	cliffBotWidth = 1,
	steepCliffWidth = 12,
	steepCliffChance = 0.01,
	bigDiffSteepCliffChance = 0.2,
	rampChance = 0.99,
	bigDiffRampChance = 0.79,
	bigDiffRampReduction = 0.9,
	rampVehWidthChance = {[2] = 0.95, [2] = 0.88, [4] = 0.55},
	impassEdgeThreshold = 380,
	------------------
	-- HEIGHT TIERS --
	------------------
	tierConst = 120,
	tierHeight = 150,
	vehPassTiers = 2, -- Update based on tierHeight
	waveDirectMult = 1,
	heightOffsetFactor = 0.9,
	mapBorderTier = 1,
	bucketBase = 1,
	bucketRandomOffset = 0.5,
	bucketStdMult = 0.9,
	bucketStdMultRand = 0.2,
	bucketSizeMult = 0.6,
	bucketSizeMultRand = 0.3,
	-----------
	-- WATER --
	-----------
	nonBorderSeaNeighbourLimit = 1, -- Allow lone lakes
	seaEdgelimit = 400,
	seaEdgelimitRepeatFactor = 0.8,
	seaLimitMaxAverageTier = -0.7, -- Most nearby area has to be sand.
	flatIglooChances = {[-1] = 1},
	flatIglooWidthMult = {[-1] = 1},
	-----------------
	-- METAL SPOTS --
	-----------------
	startPoint = {550, 550},
	startPointSize = 600,
	baseMexesPerSide = 17,
	baseMexesRand = 4,
	forcedMidMexes = 0,
	forcedMinMexRadius = 900,
	emptyAreaMexes = 5,
	emptyAreaMexRadiusMin = 1200,
	emptyAreaMexRadiusRand = 200,
	mexLoneSize = 1400,
	startMexGap = 1200, -- Gap is not size, but distance between mexes
	startMexSize = 420,
	doubleMexDetectGap = 400,
	doubleMexSize = 900,
	mexPairSize = 600,
	mexPairGapRequirement = 120,
	mexPairSizePostSize = 300,
	midMexDetectGap = 100,
	mexValue = 2.0,
	megaMexValue = 5.0,
	smallTeamMetalMult = 1.05,
	bigTeamMetalMult = 1.2,
	predefinedMexSize = 330,
	predefinedMexes = {
		{1750, 450},
		{450, 1750},
		{2850, 650},
		{650, 2850},
	},
	----------
	-- MISC --
	----------
	treeMult = 3,
	treeMinTier = 1,
	treeMaxTier = 2,
	stripeRisk = 0,
	},
}
return allParams