--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
if not gadgetHandler:IsSyncedCode() then
	return
end
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
	return {
		name      = "Map Terrain Generator",
		desc      = "Generates random terrain",
		author    = "GoogleFrog",
		date      = "14 August 2019",
		license   = "GNU GPL, v2 or later",
		layer    = -math.huge + 2,
		enabled   = true  --  loaded by default?
	}
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local MAP_X = Game.mapSizeX
local MAP_Z = Game.mapSizeZ
local MID_X = MAP_X/2
local MID_Z = MAP_Z/2
local SQUARE_SIZE = Game.squareSize

local spSetHeightMap = Spring.SetHeightMap

local sqrt   = math.sqrt
local pi     = math.pi
local cos    = math.cos
local sin    = math.sin
local abs    = math.abs
local log    = math.log
local floor  = math.floor
local ceil   = math.ceil
local min    = math.min
local max    = math.max
local random = math.random

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Configuration

local MIN_EDGE_LENGTH = 10

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Heightmap manipulation

local function FlattenMap(height)
	for x = 0, MAP_X, SQUARE_SIZE do
		for z = 0, MAP_Z, SQUARE_SIZE do
			spSetHeightMap(x, z, height)
		end
		Spring.ClearWatchDogTimer()
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Vector

local function DistSq(p1, p2)
	return (p1[1] - p2[1])^2 + (p1[2] - p2[2])^2
end

local function Dist(p1, p2)
	return sqrt(DistSq(p1, p2))
end

local function Mult(b, v)
	return {b*v[1], b*v[2]}
end

local function Add(v1, v2)
	return {v1[1] + v2[1], v1[2] + v2[2]}
end

local function Subtract(v1, v2)
	return {v1[1] - v2[1], v1[2] - v2[2]}
end

local function AbsValSq(x)
	return x[1]^2 + x[2]^2
end

local function LengthSq(line)
	return DistSq(line[1], line[2])
end

local function Length(line)
	return Dist(line[1], line[2])
end

local function AbsVal(x, y, z)
	if z then
		return sqrt(x*x + y*y + z*z)
	elseif y then
		return sqrt(x*x + y*y)
	elseif x[3] then
		return sqrt(x[1]*x[1] + x[2]*x[2] + x[3]*x[3])
	else
		return sqrt(x[1]*x[1] + x[2]*x[2])
	end
end

local function Unit(v)
	local mag = AbsVal(v)
	if mag > 0 then
		return {v[1]/mag, v[2]/mag}
	else
		return v
	end
end

local function Norm(b, v)
	local mag = AbsVal(v)
	if mag > 0 then
		return {b*v[1]/mag, b*v[2]/mag}
	else
		return v
	end
end

local function RotateLeft(v)
	return {-v[2], v[1]}
end

local function RotateVector(v, angle)
	return {v[1]*cos(angle) - v[2]*sin(angle), v[1]*sin(angle) + v[2]*cos(angle)}
end

local function Dot(v1, v2)
	if v1[3] then
		return v1[1]*v2[1] + v1[2]*v2[2] + v1[3]*v2[3]
	else
		return v1[1]*v2[1] + v1[2]*v2[2]
	end
end

local function Cross(v1, v2)
	return {v1[2]*v2[3] - v1[3]*v2[2], v1[3]*v2[1] - v1[1]*v2[3], v1[1]*v2[2] - v1[2]*v2[1]}
end

local function Cross_TwoDimensions(v1, v2)
	return v1[1]*v2[2] - v1[2]*v2[1]
end

local function Angle(x,z)
	if not z then
		x, z = x[1], x[2]
	end
	if x == 0 and z == 0 then
		return 0
	end
	local mult = 1/AbsVal(x, z)
	x, z = x*mult, z*mult
	if z > 0 then
		return math.acos(x)
	elseif z < 0 then
		return 2*math.pi - math.acos(x)
	elseif x < 0 then
		return math.pi
	end
	-- x < 0
	return 0
end

local function GetAngleBetweenUnitVectors(u, v)
	return math.acos(Dot(u, v))
end

-- Projection of v1 onto v2
local function Project(v1, v2)
	local uV2 = Unit(v2)
	return Mult(Dot(v1, uV2), uV2)
end

-- The normal of v1 onto v2. Returns such that v1 = normal + projection
local function Normal(v1, v2)
	local projection = Project(v1, v2)
	return Subtract(v1, projection), projection
end

local function GetMidpoint(p1, p2)
	if not p2 then
		p2 = p1[2]
		p1 = p1[1]
	end
	local v = Subtract(p1, p2)
	return Add(p2, Mult(0.5, v))
end

local function IsPositiveIntersect(lineInt, lineMid, lineDir)
	return Dot(Subtract(lineInt, lineMid), lineDir) > 0
end

local function DistanceToBoundedLineSq(point, line)
	local startToPos = Subtract(point, line[1])
	local startToEnd = Subtract(line[2], line[1])
	local normal, projection = Normal(startToPos, startToEnd)
	local projFactor = Dot(projection, startToEnd)
	local normalFactor = Dot(normalFactor, startToEnd)
	if projFactor < 0 then
		return Dist(line[1], point)
	end
	if projFactor > 1 then
		return Dist(line[2], point)
	end
	return AbsValSq(Subtract(startToPos, normal)), normalFactor
end

local function DistanceToBoundedLine(point, line)
	local distSq, normalFactor = DistanceToBoundedLineSq(point, line)
	return sqrt(distSq), normalFactor
end

local function DistanceToLineSq(point, line)
	local startToPos = Subtract(point, line[1])
	local startToEnd = Subtract(line[2], line[1])
	local normal, projection = Normal(startToPos, startToEnd)
	return AbsValSq(normal)
end

local function GetRandomDir()
	local angle = random()*2*pi
	return {cos(angle), sin(angle)}
end

local function GetRandomSign()
	return (math.floor(random()*2))*2 - 1
end

local function SamePoint(p1, p2, acc)
	acc = acc or 1
	return ((p1[1] - p2[1] < acc) and (p2[1] - p1[1] < acc)) and ((p1[2] - p2[2] < acc) and (p2[2] - p1[2] < acc))
end

local function SameLine(l1, l2)
	return (SamePoint(l1[1], l2[1], 5) and SamePoint(l1[2], l2[2], 5)) or (SamePoint(l1[1], l2[2], 5) and SamePoint(l1[2], l2[1], 5))
end

local function CompareLength(a, b)
	return a.length > b.length
end

local function InverseBasis(a, b, c, d)
	local det = a*d - b*c
	return d/det, -b/det, -c/det, a/det
end

local function ChangeBasis(v, a, b, c, d)
	return {v[1]*a + v[2]*b, v[1]*c + v[2]*d}
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Point manipulation

local function GetClosestPoint(point, nearPoints, useSize)
	if not nearPoints[1] then
		return false
	end
	local closeIndex = 1
	local closeDist = Dist(point, nearPoints[1])
	for i = 2, #nearPoints do
		local thisDist = Dist(point, nearPoints[i])
		if thisDist + ((useSize and nearPoints[i].size) or 0) < closeDist then
			closeIndex = i
			closeDist = thisDist
		end
	end
	
	return closeIndex, closeDist
end

local function GetClosestCell(point, nearCells)
	if not nearCells[1] then
		return false
	end
	local closeIndex = 1
	local closeDistSq = DistSq(point, nearCells[1].site)
	for i = 2, #nearCells do
		local thisDistSq = DistSq(point, nearCells[i].site)
		if thisDistSq < closeDistSq then
			closeIndex = i
			closeDistSq = thisDistSq
		end
	end
	
	return closeIndex, closeDistSq
end

local function GetClosestLine(point, nearLines, FilterFunc)
	if not nearLines[1] then
		return false
	end
	local closeIndex, closeDistSq
	for i = 1, #nearLines do
		if (not FilterFunc) or FilterFunc(nearLines[i]) then
			local thisDistSq = DistanceToLineSq(point, nearLines[i])
			if (not closeDistSq) or (thisDistSq < closeDistSq) then
				closeIndex = i
				closeDistSq = thisDistSq
			end
		end
	end
	
	return closeIndex, closeDistSq
end

local function GetPointCell(point, cells)
	if not cells[1] then
		return false
	end
	local closeIndex = 1
	local closeDistSq = DistSq(point, cells[1].site)
	for i = 2, #cells do
		local thisDistSq = DistSq(point, cells[i].site)
		if thisDistSq < closeDistSq then
			closeIndex = i
			closeDistSq = thisDistSq
		end
	end
	
	return closeIndex, closeDistSq
end

local function GetRandomPoint(avoidDist, avoidPoints, maxAttempts, useOtherSize)
	local point = {random()*MAP_X, random()*MAP_Z}
	if not avoidDist then
		return point
	end
	
	local attempts = 1
	while (select(2, GetClosestPoint(point, avoidPoints, useOtherSize)) or 0) < avoidDist do
		point = {random()*MAP_X, random()*MAP_Z}
		attempts = attempts + 1
		if attempts > maxAttempts then
			break
		end
	end
	
	return point
end

local function GetRandomPointInCircle(pos, radius, edgeBuffer)
	local randomPos = Add(pos, Mult(radius*random()^2, GetRandomDir()))
	if not edgeBuffer then
		return randomPos
	end
	
	if randomPos[1] < edgeBuffer then
		randomPos[1] = edgeBuffer
	elseif randomPos[1] > MAP_X - edgeBuffer then
		randomPos[1] = MAP_X - edgeBuffer
	end
	
	if randomPos[2] < edgeBuffer then
		randomPos[2] = edgeBuffer
	elseif randomPos[2] > MAP_Z - edgeBuffer then
		randomPos[2] = MAP_Z - edgeBuffer
	end
	
	return randomPos
end

local function ApplyRotSymmetry(p1, p2)
	if not p2 then
		return {MAP_X - p1[1], MAP_Z - p1[2]}
	end
	return {ApplyRotSymmetry(p1), ApplyRotSymmetry(p2)}
end

local function GetBoundedLineIntersection(line1, line2)
	local x1, y1, x2, y2 = line1[1][1], line1[1][2], line1[2][1], line1[2][2]
	local x3, y3, x4, y4 = line2[1][1], line2[1][2], line2[2][1], line2[2][2]
	
	local denominator = ((x1 - x2)*(y3 - y4) - (y1 - y2)*(x3 - x4))
	if denominator == 0 then
		return false
	end
	local first = ((x1 - x3)*(y3 - y4) - (y1 - y3)*(x3 - x4))/denominator
	local second = -1*((x1 - x2)*(y1 - y3) - (y1 - y2)*(x1 - x3))/denominator
	
	if first < 0 or first > 1 or (second < 0 or second > 1) then
		return false
	end
	
	local px = x1 + first*(x2 - x1)
	local py = y1 + first*(y2 - y1)
	
	return {px, py}
end

local function InMapBounds(point)
	return not (point[1] < 0 or point[2] < 0 or point[1] > MAP_X or point[2] > MAP_Z)
end

local function GetPosIndex(x, z)
	return x + (MAP_X + 1)*z
end

local function EdgeAdjacentToCellIndex(edge, cellIndex)
	for i = 1, #edge.faces do
		if edge.faces[i].index == cellIndex then
			return true
		end
	end
	return false
end

local function GetClockwiseIntAndEdge(edge, cellIndex)
	for n = 1, #edge.neighbours do
		local nbhd = edge.neighbours[n]
		for i = 1, #nbhd do
			local otherEdge = nbhd[i]
			if edge.clockwiseNeighbour[otherEdge.index] and EdgeAdjacentToCellIndex(otherEdge, cellIndex) then
				return edge[n], otherEdge
			end
		end
	end
end

local function GetCellVertices(cell)
	local cellIndex = cell.index
	local startEdge = cell.edges[1]
	local points = {}
	
	local intPoint, thisEdge = GetClockwiseIntAndEdge(startEdge, cellIndex)
	points[#points + 1] = intPoint
	
	while thisEdge.index ~= startEdge.index do
		intPoint, thisEdge = GetClockwiseIntAndEdge(thisEdge, cellIndex)
		points[#points + 1] = intPoint
	end
	
	return points
end

local function AveragePoints(points)
	local sumX = 0
	local sumZ = 0
	for i = 1, #points do
		sumX = sumX + points[i][1]
		sumZ = sumZ + points[i][2]
	end
	
	return {sumX/#points, sumZ/#points}
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Baked Tables

local OUTER_POINTS = {
	{ -4*MAP_X,  -4*MAP_Z},
	{ -4*MAP_X,   5*MAP_Z},
	{  5*MAP_X,  -4*MAP_Z},
	{  5*MAP_X,   5*MAP_Z},
}

local MAP_BORDER = {
	{{-10*MAP_X,     0}, {10*MAP_X,     0}},
	{{-10*MAP_X, MAP_Z}, {10*MAP_X, MAP_Z}},
	{{    0, -10*MAP_Z}, {    0, 10*MAP_Z}},
	{{MAP_X, -10*MAP_Z}, {MAP_X, 10*MAP_Z}},
}

local POINT_COUNT = 15
local CIRCLE_POINTS = {}
for i = pi, pi*3/2 + pi/(4*POINT_COUNT), pi/(2*POINT_COUNT) do
	CIRCLE_POINTS[#CIRCLE_POINTS + 1] = {1 + cos(i), 1 + sin(i)}
end

local STRAIGHT_EDGE_POINTS = 18

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Voronoi

local function GetBoundedLine(pos, dir, bounder)
	local line = {Add(pos, Mult(50*MAP_X, dir)), Add(pos, Mult(-50*MAP_X, dir))}
	return line
end

local function GetBoundingCells()
	local cells = {}
	for i = 1, #OUTER_POINTS do
		local newCell = {
			site = OUTER_POINTS[i],
			edges = {},
		}
		local cellCorners = {
			{-4.5*MAP_X, -4.5*MAP_Z},
			{ 4.5*MAP_X, -4.5*MAP_Z},
			{ 4.5*MAP_X,  4.5*MAP_Z},
			{-4.5*MAP_X,  4.5*MAP_Z},
		}
		
		local sx, sz = newCell.site[1], newCell.site[2]
		for j = 1, #cellCorners do
			newCell.edges[#newCell.edges + 1] = {Add(newCell.site, cellCorners[j]), Add(newCell.site, cellCorners[(j%4) + 1])}
		end
		cells[#cells + 1] = newCell
	end
	
	local offset = {10*MAP_X, 10*MAP_Z}
	
	return cells
end

local function GenerateVoronoiCells(points)
	local outerCells = GetBoundingCells()
	local cells = {}
	local edgeIndex = 0
	
	for i = 1, #points do
		local newCell = {
			site = points[i],
			edges = {},
		}
		for j = 1 - #outerCells, #cells do
			local otherCell = (j > 0 and cells[j]) or outerCells[j + #outerCells]
			local pos = GetMidpoint(newCell.site, otherCell.site)
			local dir = RotateLeft(Unit(Subtract(newCell.site, otherCell.site)))
			local line = GetBoundedLine(pos, dir, OUTER_BOUNDS)
			
			local intersections = false
			for k = #otherCell.edges, 1, -1 do
				local otherEdge = otherCell.edges[k]
				local int = GetBoundedLineIntersection(line, otherEdge)
				if int then
					if GetBoundedLineIntersection(line, {otherEdge[1], otherCell.site}) then
						otherCell.edges[k] = {int, otherCell.edges[k][2], otherCell.edges[k][3]}
					else
						otherCell.edges[k] = {otherCell.edges[k][1], int, otherCell.edges[k][3]}
					end
					intersections = intersections or {}
					intersections[#intersections + 1] = int
				else
					if GetBoundedLineIntersection(line, {otherEdge[1], otherCell.site}) then
						otherCell.edges[k] = otherCell.edges[#otherCell.edges]
						otherCell.edges[#otherCell.edges] = nil
					end
				end
			end
			if intersections then
				if #intersections ~= 2 then
					for e = 1, #cells do
						CellEcho(cells[e])
					end
					for e = 1, #intersections do
						PointEcho(intersections[e], "Int: " .. e)
					end
					Spring.Echo("#intersections ~= 2", #intersections)
					return
				end
				newCell.edges[#newCell.edges + 1] = intersections
				otherCell.edges[#otherCell.edges + 1] = intersections
				
				edgeIndex = edgeIndex + 1
				intersections[3] = edgeIndex
			end
		end
		cells[#cells + 1] = newCell
	end
	
	return cells
end

local function BoundExtendedVoronoiToMapEdge(cells)
	for i = 1, #MAP_BORDER do
		local borderLine = MAP_BORDER[i]
		for j = #cells, 1, -1 do
			local thisCell = cells[j]
			local intersections = false
			for k = #thisCell.edges, 1, -1 do
				local thisEdge = thisCell.edges[k]
				local int = GetBoundedLineIntersection(borderLine, thisEdge)
				if int then
					if GetBoundedLineIntersection(borderLine, {thisEdge[1], thisCell.site}) then
						thisCell.edges[k] = {int, thisCell.edges[k][2], thisCell.edges[k][3]}
					else
						thisCell.edges[k] = {thisCell.edges[k][1], int, thisCell.edges[k][3]}
					end
					intersections = intersections or {}
					intersections[#intersections + 1] = int
				else
					if GetBoundedLineIntersection(borderLine, {thisEdge[1], thisCell.site}) then
						thisCell.edges[k] = thisCell.edges[#thisCell.edges]
						thisCell.edges[#thisCell.edges] = nil
					end
				end
			end
			if intersections then
				thisCell.edges[#thisCell.edges + 1] = intersections
			end
		end
	end
	return cells
end

local function CleanVoronoiReferences(cells)
	local edgeList = {}
	local edgesAdded = {}
	
	-- Enter mirror cell
	for i = 1, #cells do
		cells[i].neighbours = {}
		cells[i].index = i
		cells[i].mirror = cells[cells[i].site.mirror]
		cells[i].site.mirror = nil
	end
	
	-- Find cell neighbours and edge faces.
	for i = 1, #cells do
		local thisCell = cells[i]
		for j = 1, #thisCell.edges do
			local thisEdge = thisCell.edges[j]
			if thisEdge[3] and edgesAdded[thisEdge[3]] then -- Check for edgeIndex
				thisEdge = edgesAdded[thisEdge[3]]
				thisCell.edges[j] = thisEdge
				
				if thisEdge.faces[1] then
					local otherCell = thisEdge.faces[1]
					otherCell.neighbours[#otherCell.neighbours + 1] = thisCell
					thisCell.neighbours[#thisCell.neighbours + 1] = otherCell
				end
				
				thisEdge.faces[#thisEdge.faces + 1] = thisCell
			else
				edgeList[#edgeList + 1] = thisEdge
				thisEdge.faces = {thisCell}
				if thisEdge[3] then
					edgesAdded[thisEdge[3]] = thisEdge
				end
			end
		end
	end
	
	-- Set edge length and faces
	for i = 1, #edgeList do
		local thisEdge = edgeList[i]
		thisEdge.index = i
		thisEdge.length = Length(thisEdge)
		thisEdge.unit   = Unit(Subtract(thisEdge[2], thisEdge[1]))
		thisEdge.otherFace = {}
		if thisEdge.faces[2] then
			for j = 1, #thisEdge.faces do
				thisEdge.otherFace[thisEdge.faces[j].index] = thisEdge.faces[3 - j]
			end
			if thisEdge.faces[1].mirror == thisEdge.faces[2] then
				thisEdge.faces[1].adjacentToMirror = true
				thisEdge.faces[2].adjacentToMirror = true
			end
		else
			if thisEdge.faces[1].adjacentToBorder then
				thisEdge.faces[1].adjacentToCorner = true
			end
			thisEdge.faces[1].adjacentToBorder = true
		end
		
		if thisEdge.length < MIN_EDGE_LENGTH then
			return cells, edgeList, thisEdge.faces[random(1, #thisEdge.faces)].index
		end
	end
	
	-- Set edge neighbours
	for i = 1, #edgeList do
		local thisEdge = edgeList[i]
		thisEdge.neighbours = {
			[1] = {},
			[2] = {},
		}
		thisEdge.clockwiseNeighbour = {}
		thisEdge.incidentEnd = {}
		
		for j = 1, #thisEdge.faces do
			local thisCell = thisEdge.faces[j]
			for k = 1, #thisCell.edges do
				local otherEdge = thisCell.edges[k]
				if otherEdge.index ~= thisEdge.index then
					for n = 1, #thisEdge.neighbours do
						local thisNbhd = thisEdge.neighbours[n]
						local otherN = (SamePoint(thisEdge[n], otherEdge[1]) and 1) or (SamePoint(thisEdge[n], otherEdge[2]) and 2)
						if otherN then
							thisEdge.clockwiseNeighbour[otherEdge.index] = (Cross_TwoDimensions(Subtract(thisEdge[3 - n], thisEdge[n]), Subtract(otherEdge[3 - otherN], otherEdge[otherN])) > 0)
							thisEdge.incidentEnd[otherEdge.index] = otherN
							
							thisNbhd[#thisNbhd + 1] = otherEdge
							if (otherEdge.faces[1].index ~= thisEdge.faces[1].index) and (otherEdge.faces[1].index ~= (thisEdge.faces[2] and thisEdge.faces[2].index)) then
								thisNbhd.endFace = otherEdge.faces[1]
							elseif otherEdge.faces[2] and (otherEdge.faces[2].index ~= thisEdge.faces[1].index) and (otherEdge.faces[2].index ~= (thisEdge.faces[2] and thisEdge.faces[2].index)) then
								thisNbhd.endFace = otherEdge.faces[2]
							end
						end
					end
				end
			end
		end
	end
	
	-- Find edge mirror
	for i = 1, #cells do
		local thisCell = cells[i]
		local mirrorCell = thisCell.mirror
		if mirrorCell then
			for j = 1, #thisCell.edges do
				local thisEdge = thisCell.edges[j]
				local rotLine = ApplyRotSymmetry(thisEdge[1], thisEdge[2])
				for k = 1, #mirrorCell.edges do
					local otherEdge = mirrorCell.edges[k]
					if SameLine(otherEdge, rotLine) then
						thisEdge.mirror = otherEdge
						otherEdge.mirror = thisEdge
						break
					end
				end
			end
		end
	end
	
	-- Some useful cell parameters.
	for i = 1, #cells do
		local thisCell = cells[i]
		thisCell.vertices = GetCellVertices(thisCell)
		thisCell.averageMid = AveragePoints(thisCell.vertices)
		thisCell.firstMirror = ((not thisCell.mirror) or (thisCell.index < thisCell.mirror.index))
	end
	
	return cells, edgeList
end

local function MakeRandomPoints(pointNum, minSpacing, maxSpacing)
	local points = {}
	local avoidDist = maxSpacing
	for i = 1, pointNum do
		local point = GetRandomPoint(avoidDist, points, 50, true)
		local pointMirror = ApplyRotSymmetry(point)
		
		point.size = avoidDist
		pointMirror.size = avoidDist
		
		points[#points + 1] = point
		pointMirror.mirror = #points
		points[#points + 1] = pointMirror
		point.mirror = #points
		
		avoidDist = avoidDist - (maxSpacing - minSpacing)/pointNum
	end
	
	return points
end

local function GetVoronoi(pointNum, minSpacing, maxSpacing)
	local points = MakeRandomPoints(pointNum, minSpacing, maxSpacing)
	
	local cells, edges, badSite = CleanVoronoiReferences(BoundExtendedVoronoiToMapEdge(GenerateVoronoiCells(points)))
	while badSite do
		points = {}
		for i = 1, #cells do
			local thisCell = cells[i]
			if thisCell.site and (thisCell.index ~= badSite) and ((not thisCell.mirror) or (thisCell.mirror.index ~= badSite)) then
				local point = {thisCell.site[1], thisCell.site[2]}
				local pointMirror = ApplyRotSymmetry(point)
				
				points[#points + 1] = point
				pointMirror.mirror = #points
				points[#points + 1] = pointMirror
				point.mirror = #points
				
				thisCell.site = nil
				if thisCell.mirror then
					thisCell.mirror.site = nil
				end
			end
		end
		
		cells, edges, badSite = CleanVoronoiReferences(BoundExtendedVoronoiToMapEdge(GenerateVoronoiCells(points)))
	end
	return cells, edges
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Base terrain generation

local function GetWave(translational, params)
	local spread = params.spread or ((params.spreadMin or 1) + ((params.spreadMax or 1) - (params.spreadMin or 1))*random())
	local scale  = params.scale  or ((params.scaleMin  or 1) + ((params.scaleMax  or 1) - (params.scaleMin  or 1))*random())
	local period = params.period or ((params.periodMin or 1) + ((params.periodMax or 1) - (params.periodMin or 1))*random())
	local offset = params.offset or ((params.offsetMin or 1) + ((params.offsetMax or 1) - (params.offsetMin or 1))*random())
	local growth = params.growth or ((params.growthMin or 1) + ((params.growthMax or 1) - (params.growthMin or 1))*random())

	scale = scale*GetRandomSign()
	growth = growth*GetRandomSign()
	
	--Spring.Echo("scale", scale, "period", period, "offset", offset, "growth", growth)
	-- Growth is increase in amplitude per (unmodified) peak-to-peak distance.
	growth = growth/period
	
	-- Period is peak-to-peak distance.
	period = period/(2*pi)
	
	local dir, wavePeriod, zeroAngle, stretchReduction
	
	if translational then
		dir =  translational and GetRandomDir()
		wavePeriod = translational and math.ceil(params.wavePeriod or ((params.wavePeriodMin or 1) + ((params.wavePeriodMax or 1) - (params.wavePeriodMin or 1))*random()))
		wavePeriod = wavePeriod/(2*pi)
	else
		zeroAngle = (not translational) and random()*2*pi
		local waveRotations = (not translational) and (params.waveRotations or ((params.waveRotationsMin or 1) + ((params.waveRotationsMax or 1) - (params.waveRotationsMin or 1))*random()))
		waveRotations = math.ceil(waveRotations/2)*2 -- Must be even for twofold rotational symmetry
		wavePeriod = 1/waveRotations
		
		spread = spread/(period*(2*pi))
		stretchReduction = spread/2
	end
	
	local function GetValue(x, z)
		x = x - MID_X
		z = z - MID_Z
		
		local normal, tangent
		if translational then
			normal  = dir[1]*x + dir[2]*z
			tangent = dir[1]*z - dir[2]*x
			
			-- Implement translate spread
			normal = abs(normal - sin(tangent/wavePeriod)*spread)
		else
			normal  = sqrt(x^2 + z^2)
			normal  = (normal*normal)/(180 + normal)
			tangent = Angle(x,z) + zeroAngle
			-- *(normal/(normal + stretchReduction))
			-- Implement scale spread
			normal = abs(normal*(1 + sin(tangent/wavePeriod)*spread))
		end
		
		return -1*(cos((normal/period)) - 1)*(normal*growth + scale) + offset
	end
	
	return GetValue
end

local function GetTranslationalWave(params)
	return GetWave(true, params)
end

local function GetRotationalWave(params)
	return GetWave(false, params)
end

local function GetTerrainWaveFunction()
	local multParams = {
		scaleMin = 0.3,
		scaleMax = 0.8,
		periodMin = 2000,
		periodMax = 5000,
		spreadMin = 200,
		spreadMax = 1200,
		offsetMin = -0.2,
		offsetMax = 0.2,
		growthMin = 0.15,
		growthMax = 0.2,
		wavePeriodMin = 1000,
		wavePeriodMax = 2600,
		waveRotationsMin = 1,
		waveRotationsMax = 8,
	}
	
	local params = {
		scaleMin = 30,
		scaleMax = 60,
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
	}
	
	local rotParams = {
		scaleMin = 30,
		scaleMax = 60,
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
	}

	local bigMultParams = {
		scaleMin = 0.7,
		scaleMax = 1,
		periodMin = 18000,
		periodMax = 45000,
		spreadMin = 2000,
		spreadMax = 8000,
		offsetMin = 0.3,
		offsetMax = 0.4,
		growthMin = 0.02,
		growthMax = 0.2,
		wavePeriodMin = 2000,
		wavePeriodMax = 5000,
		waveRotationsMin = 1,
		waveRotationsMax = 8,
	}
	
	local rotMult = GetRotationalWave(multParams)
	local transMult = GetTranslationalWave(multParams)

	local rot = GetRotationalWave(rotParams)
	local trans = GetTranslationalWave(params)
	params.periodMin = params.periodMin*1.6
	params.periodMax = params.periodMax*1.6
	
	local trans2 = GetTranslationalWave(params)
	local transMult2 = GetTranslationalWave(multParams)
	params.periodMin = params.periodMin*1.6
	params.periodMax = params.periodMax*1.6
	
	local trans3 = GetTranslationalWave(params)
	local rotMult3 = GetRotationalWave(multParams)
	params.periodMin = params.periodMin*1.6
	params.periodMax = params.periodMax*1.6
	
	local bigMult = GetTranslationalWave(bigMultParams)
	
	local function GetValue(x, z)
		--return rot(x,z)*5 + 70
		return 1.25*(rot(x,z)*transMult(x,z) + trans(x,z)*rotMult(x,z) + bigMult(x,z)*(trans2(x,z)*transMult2(x,z) + trans3(x,z)*rotMult3(x,z)) + 70)
	end
	
	return GetValue
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Write terrain

local function TerraformByFunc(func)
	local function DoTerra()
		for x = 0, MAP_X, SQUARE_SIZE do
			for z = 0, MAP_Z, SQUARE_SIZE do
				spSetHeightMap(x, z, func(x, z))
			end
			Spring.ClearWatchDogTimer()
		end
	end
	
	Spring.SetHeightMapFunc(DoTerra)
end

local function TerraformByHeights(heights)
	local minHeight, maxHeight = 4000, -4000

	local function DoTerra()
		for x = 0, MAP_X, SQUARE_SIZE do
			for z = 0, MAP_Z, SQUARE_SIZE do
				local h = heights[x][z]
				spSetHeightMap(x, z, h or 600)
				if h < minHeight then
					minHeight = h
				end
				if h > maxHeight then
					maxHeight = h
				end
			end
			Spring.ClearWatchDogTimer()
		end
		
		Spring.SetGameRulesParam("ground_min_override", minHeight)
		Spring.SetGameRulesParam("ground_max_override", maxHeight)
	end

	Spring.SetHeightMapFunc(DoTerra)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Floodfill handler

local function GetFloodfillHandler(defaultValue)
	local values = {}
	local influenceDist = {}
	local fillX = {}
	local fillZ = {}
	
	local ORTH_X = {-8,  0, 8, 0}
	local ORTH_Z = { 0, -8, 0, 8}
	
	local function CheckAndFillNearby(x, z, val)
		for i = 1, 4 do
			local nx, nz = x + ORTH_X[i], z + ORTH_Z[i]
			if (nx >= 0 and nz >= 0 and nx <= MAP_X and nz <= MAP_Z) and not (values[nx] and values[nx][nz]) then
				values[nx] = values[nx] or {}
				values[nx][nz] = val
				fillX[#fillX + 1] = nx
				fillZ[#fillZ + 1] = nz
			end
		end
	end
	
	local externalFuncs = {}
	
	function externalFuncs.AddHeight(x, z, val, dist)
		if (x >= 0 and z >= 0 and x <= MAP_X and z <= MAP_Z) and ((not (influenceDist[x] and influenceDist[x][z])) or (dist < influenceDist[x][z])) then
			influenceDist[x] = influenceDist[x] or {}
			influenceDist[x][z] = dist
			values[x] = values[x] or {}
			values[x][z] = val
			
			fillX[#fillX + 1] = x
			fillZ[#fillZ + 1] = z
			--Spring.MarkerAddPoint(x, 0, z, val)
		end
	end
	
	function externalFuncs.RunFloodfillAndGetValues()
		if #fillX == 0 then
			for x = 0, MAP_X, SQUARE_SIZE do
				values[x] = {}
				for z = 0, MAP_Z, SQUARE_SIZE do
					values[x][z] = defaultValue
				end
			end
		end
		while #fillX > 0 do
			local x, z = fillX[#fillX], fillZ[#fillZ]
			fillX[#fillX], fillZ[#fillZ] = nil, nil
			CheckAndFillNearby(x, z, values[x][z])
		end
		return values
	end
	
	return externalFuncs
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Process Edges

local function GetSlopeWidth(startWidth, endWidth, startDist, endDist, dist)
	local propDist = startDist + dist*(endDist - startDist)
	if propDist < startDist then
		propDist = startDist
	elseif propDist > endDist then
		propDist = endDist
	end
	
	local prop = (cos(((propDist - 0.15)/0.7)*pi) + 1)/2
	if propDist < 0.15 then
		prop = 1
	elseif propDist > 0.85 then
		prop = 0
	end
	
	return prop*startWidth + (1 - prop)*endWidth
end

local function MakeEdgeSlope(tangDist, projDist, length, startWidth, endWidth, segStartWidth, segEndWidth, startDist, endDist, overshootStart)
	local maxWidth = max(segStartWidth, segEndWidth)
	
	if tangDist < -maxWidth then
		return
	end
	if tangDist > maxWidth then
		return
	end
	
	local dist = abs(tangDist)
	local width = GetSlopeWidth(startWidth, endWidth, startDist, endDist, projDist/length)
	local sign = ((tangDist > 0) and 1) or -1
	
	if dist > width then
		return
	end
	
	if (projDist < 0 and (not overshootStart)) or (projDist > length) then
		width = ((projDist < 0) and segStartWidth) or segEndWidth
		local offDist = ((projDist < 0) and -projDist) or (projDist - length)
		dist = sqrt(offDist^2 + dist^2)
		if dist > width then
			return
		end
	end
	
	local change = (1 - cos(pi*(sign*dist/2 + width/2)/width))/2
	if change > 0.5 then
		return false, (1 - change)
	else
		return change, false
	end
end

local function ApplyLineDistanceFunc(tierFlood, cellTier, otherTier, heightMod, lineStart, lineEnd, HeightFunc, startWidth, endWidth, startDist, endDist, otherClockwise, overshootStart)
	local segStartWidth = GetSlopeWidth(startWidth, endWidth, startDist, endDist, 0)
	local segEndWidth   = GetSlopeWidth(startWidth, endWidth, startDist, endDist, 1)
	local width = max(segStartWidth, segEndWidth)
	
	if overshootStart then
		width = width*2
	end
	
	local left  = floor((min(lineStart[1], lineEnd[1]) - width)/8)*8
	local right =  ceil((max(lineStart[1], lineEnd[1]) + width)/8)*8
	local top   = floor((min(lineStart[2], lineEnd[2]) - width)/8)*8
	local bot   =  ceil((max(lineStart[2], lineEnd[2]) + width)/8)*8

	local lineVector = Subtract(lineEnd, lineStart)
	local unitProjection = Unit(lineVector)
	local unitTanget = RotateLeft(unitProjection)
	local pdx, pdz = unitProjection[1], unitProjection[2]
	local tdx, tdz = unitTanget[1], unitTanget[2]
	local ox, oz = lineStart[1], lineStart[2]
	local ex, ez = lineEnd[1], lineEnd[2]
	
	local lineLength = AbsVal(lineVector)
	
	otherClockwise = ((otherClockwise and true) or false)
	
	for x = left, right, 8 do
		for z = top, bot, 8 do
			local vx, vz = x - ox, z - oz
			local projDist = vx*pdx + vz*pdz
			local tangDist = vx*tdx + vz*tdz
			
			if not otherClockwise then
				tangDist = -tangDist
			end
			local tangDistAbs = abs(tangDist)
			if projDist > -8 and projDist < lineLength + 8 and tangDist > -20 and tangDist < 40 then
				if projDist < 0 then
					tangDistAbs = tangDistAbs - projDist*3
				elseif projDist > lineLength then
					tangDistAbs = tangDistAbs + (projDist - lineLength)*3
				end
				
				tierFlood.AddHeight(x, z, ((tangDist > 0) and cellTier) or otherTier, tangDistAbs)
			end
			
			
			local towardsCellTier, towardsOtherTier = HeightFunc(tangDist, projDist, lineLength, startWidth, endWidth, segStartWidth, segEndWidth, startDist, endDist, overshootStart)
			local posIndex = GetPosIndex(x, z)
			
			if towardsCellTier then
				heightMod[posIndex] = heightMod[posIndex] or {}
				if ((not heightMod[posIndex][cellTier]) or heightMod[posIndex][cellTier] < towardsCellTier) then
					heightMod[posIndex][cellTier] = towardsCellTier
				end
			end
			
			if towardsOtherTier then
				heightMod[posIndex] = heightMod[posIndex] or {}
				if ((not heightMod[posIndex][otherTier]) or heightMod[posIndex][otherTier] < towardsOtherTier) then
					heightMod[posIndex][otherTier] = towardsOtherTier
				end
			end
		end
	end
end

local function GetLineHeightModifiers(tierFlood, cellTier, otherTier, heightMod, startPoint, endPoint, width, otherClockwise)
	ApplyLineDistanceFunc(tierFlood, cellTier, otherTier, heightMod, startPoint, endPoint, MakeEdgeSlope, width, width, 0, 1, otherClockwise, true)
end

local function GetCurveHeightModifiers(tierFlood, cellTier, otherTier, heightMod, curve, startWidth, endWidth, otherClockwise)
	local curveDist = {}
	local totalLength = 0
	for i = 1, #curve do
		curveDist[i] = totalLength
		if curve[i + 1] then
			local segmentLength = Dist(curve[i], curve[i + 1])
			totalLength = totalLength + segmentLength
		end
	end
	for i = 1, #curve - 1 do
		local startDist = curveDist[i]/totalLength
		local endDist = curveDist[i+1]/totalLength
		ApplyLineDistanceFunc(tierFlood, cellTier, otherTier, heightMod, curve[i], curve[i + 1], MakeEdgeSlope, startWidth, endWidth, startDist, endDist, otherClockwise, false)
	end
end

local function GetEdgeBoundary(tierFlood, heightMod, cells, cell, edge, otherEdge, edgeIncidence)
	local cellIndex = cell.index
	local intPoint = edge[edgeIncidence]
	
	local otherIncidence = edge.incidentEnd[otherEdge.index]
	local edgeOut  = Mult((-edgeIncidence  + 1.5)*edge.length,      edge.unit)
	local otherOut = Mult((-otherIncidence + 1.5)*otherEdge.length, otherEdge.unit)
	
	local otherClockwise = (edge.clockwiseNeighbour[otherEdge.index])
	local cellTier = cell.tier
	
	if not (edge.otherFace[cellIndex]) then
		if not (otherEdge.otherFace[cellIndex]) then
			return
		end
		if cell.tier == otherEdge.otherFace[cellIndex].tier then
			return
		end
		if Dot(edgeOut, otherOut) < 0 then
			return
		end
		local otherTier = otherEdge.otherFace[cellIndex].tier
		otherClockwise = not otherClockwise
		GetLineHeightModifiers(tierFlood, cellTier, otherTier, heightMod, intPoint, Add(intPoint, otherOut), otherEdge.terrainWidth, otherClockwise)
		return
	end
	
	if not (otherEdge.otherFace[cellIndex]) then
		if cell.tier == edge.otherFace[cellIndex].tier then
			return
		end
		if Dot(edgeOut, otherOut) < 0 then
			return
		end
		local otherTier = edge.otherFace[cellIndex].tier
		GetLineHeightModifiers(tierFlood, cellTier, otherTier, heightMod, intPoint, Add(intPoint, edgeOut), edge.terrainWidth, otherClockwise)
		return
	end
	
	local topOfCliff = (cellTier > edge.otherFace[cellIndex].tier and cellTier > otherEdge.otherFace[cellIndex].tier)
	local bottomOfCliff = (cellTier < edge.otherFace[cellIndex].tier and cellTier < otherEdge.otherFace[cellIndex].tier)
	local doubleCliff = bottomOfCliff and edge.otherFace[cellIndex].tier ~= otherEdge.otherFace[cellIndex].tier
	
	if not (topOfCliff or bottomOfCliff) then
		return
	end
	
	local otherTier = (topOfCliff    and max(edge.otherFace[cellIndex].tier, otherEdge.otherFace[cellIndex].tier)) or
	                  (bottomOfCliff and min(edge.otherFace[cellIndex].tier, otherEdge.otherFace[cellIndex].tier))
	
	local curve = {}
	for i = 1, #CIRCLE_POINTS do
		curve[#curve + 1] = Add(intPoint, ChangeBasis(CIRCLE_POINTS[i], edgeOut[1], otherOut[1], edgeOut[2], otherOut[2]))
		--PointEcho(curve[#curve], i)
	end
	
	--PointEcho(intPoint, "E: " .. edge.terrainWidth .. ", O: " .. otherEdge.terrainWidth .. "," .. MakeBoolString({otherClockwise}))
	GetCurveHeightModifiers(tierFlood, cellTier, otherTier, heightMod, curve, otherEdge.terrainWidth, edge.terrainWidth, otherClockwise)
end

local function GetSharedCell(edge, other)
	if (edge.faces[1].index == other.faces[1].index) or (other.faces[2] and (edge.faces[1].index == other.faces[2].index)) then
		return edge.faces[1]
	end
	
	if edge.faces[2] and ((edge.faces[2].index == other.faces[1].index) or (other.faces[2] and (edge.faces[2].index == other.faces[2].index))) then
		return edge.faces[2]
	end
	
	return false
end

local function ProcessEdges(cells, edges)
	local heightMod = {}
	local tierFlood = GetFloodfillHandler(cells[1].tier)
	for i = 1, #edges do
		local thisEdge = edges[i]
		for n = 1, #thisEdge.neighbours do
			local nbhd = thisEdge.neighbours[n]
			for j = 1, #nbhd do
				local otherEdge = nbhd[j]
				if otherEdge.index < thisEdge.index then
					GetEdgeBoundary(tierFlood, heightMod, cells, GetSharedCell(thisEdge, otherEdge), thisEdge, otherEdge, n)
				end
			end
		end
	end
	
	return tierFlood, heightMod
end

local function MirrorEdgePassability(edge)
	local mirror = edge.mirror
	if not mirror then
		return
	end

	mirror.terrainWidth = edge.terrainWidth
	mirror.teirDiff     = edge.teirDiff
	mirror.highTeir     = edge.highTeir
	mirror.vehPass      = edge.vehPass
	mirror.botPass      = edge.botPass
	mirror.landPass     = edge.landPass
end

local CLIFF_WIDTH = 25
local RAMP_WIDTH  = 320

local function SetEdgePassability(edge)
	edge.teirDiff = (edge.faces and (#edge.faces == 2) and abs(edge.faces[1].tier - edge.faces[2].tier)) or 0
	edge.highTeir = edge.faces and (#edge.faces == 2) and max(edge.faces[1].tier, edge.faces[2].tier)
	edge.lowTeir = edge.faces and (#edge.faces == 2) and min(edge.faces[1].tier, edge.faces[2].tier)
	if not edge.highTeir then
		edge.highTeir = edge.faces[1].tier
		edge.lowTeir = edge.faces[1].tier
	end
	edge.landPass = (edge.lowTeir >= -1)
	
	if edge.teirDiff == 0 then
		edge.vehPass = true
		edge.botPass = true
		edge.terrainWidth = 20
		return
	end
	
	local impassCount = 0
	local matchCount  = 0
	for n = 1, 2 do
		local nbhd = edge.neighbours[n]
		for i = 1, #nbhd do
			local otherEdge = nbhd[i]
			if otherEdge.teirDiff ~= 0 and otherEdge.highTeir == edge.highTeir then
				matchCount = matchCount + 1
				if otherEdge.terrainWidth < 100 then
					impassCount = impassCount + 1
				end
			end
		end
	end
	
	if edge.length < 600 and ((impassCount == 0) or (matchCount - impassCount == 0)) then
		edge.terrainWidth = ((impassCount == 0) and RAMP_WIDTH) or CLIFF_WIDTH
	else
		edge.terrainWidth = ((random() > 0.35) and RAMP_WIDTH) or CLIFF_WIDTH
	end
	
	if edge.teirDiff >= 2 and edge.teirDiff <= 3 then
		if edge.terrainWidth >= RAMP_WIDTH then
			if (random() > 0.5) then
				edge.terrainWidth = edge.terrainWidth*edge.teirDiff*1.4
			end
		elseif edge.terrainWidth <= CLIFF_WIDTH then
			edge.terrainWidth = edge.terrainWidth*edge.teirDiff
		end
	end
	
	if (edge.terrainWidth/edge.teirDiff <= CLIFF_WIDTH) or (edge.teirDiff > 3) then
		edge.vehPass = false
		edge.botPass = false
	elseif (edge.terrainWidth/edge.teirDiff >= RAMP_WIDTH) then
		edge.vehPass = true
		edge.botPass = true
	else
		edge.vehPass = false
		edge.botPass = true
	end
	
end

local function GenerateEdgePassability(edgesSorted)
	-- Smallest to largest
	for i = #edgesSorted, 1, -1 do
		local thisEdge = edgesSorted[i]
		if not thisEdge.terrainWidth then
			SetEdgePassability(thisEdge)
			MirrorEdgePassability(thisEdge)
		end
	end
end

local function GetHeightMod(tierMin, tierMax, posTier, posChange, x, z)
	if not posChange then
		return 0
	end
	
	local tierChange = 0
	local recentChange = false
	for tier = tierMax, posTier + 1, -1 do
		if posChange[tier] then
			recentChange = (recentChange and max(recentChange, posChange[tier])) or posChange[tier]
			tierChange = tierChange + recentChange
		elseif recentChange then
			tierChange = tierChange + recentChange
		end
	end
	
	recentChange = false
	for tier = tierMin, posTier - 1 do
		if posChange[tier] then
			recentChange = (recentChange and min(recentChange, -posChange[tier])) or -posChange[tier]
			tierChange = tierChange + recentChange
		elseif recentChange then
			tierChange = tierChange + recentChange
		end
	end
	
	return tierChange
end

local function ApplyHeightModifiers(tierConst, tierHeight, tierMin, tierMax, tiers, heightMod, waveFunc, waveMult)
	local heights = {}
	
	for x = 0, MAP_X, SQUARE_SIZE do
		heights[x] = {}
		for z = 0, MAP_Z, SQUARE_SIZE do
			local posIndex = GetPosIndex(x, z)
			local baseHeight = tierConst + tierHeight*tiers[x][z]
			local change = GetHeightMod(tierMin, tierMax, tiers[x][z], heightMod[posIndex], x, z)
			
			heights[x][z] = baseHeight + tierHeight*change + ((waveFunc and waveFunc(x, z)*waveMult) or 0)
		end
	end
	
	return heights
end

local function ApplyHeightSmooth(rawHeights, filter)
	local heights = {}
	local filterSum = 0
	for i = 1, #filter do
		filterSum = filterSum + filter[i][3]
	end
	local filterMult = 1/filterSum
	
	for x = 0, MAP_X, SQUARE_SIZE do
		heights[x] = {}
		for z = 0, MAP_Z, SQUARE_SIZE do
			local thisHeight = rawHeights[x][z]
			local heightSum = 0
			for i = 1, #filter do
				local sx, sz = x + filter[i][1], z + filter[i][2]
				heightSum = heightSum + ((rawHeights[sx] and rawHeights[sx][sz]) or thisHeight)*filter[i][3]
			end
			heights[x][z] = heightSum*filterMult
		end
	end
	
	return heights
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Voronoi heights

local function GenerateCellTiers(cells, waveFunc)
	local averageheight = 0
	for i = 1, #cells do
		local height = waveFunc(cells[i].site[1], cells[i].site[2])
		averageheight = averageheight + height
	end
	averageheight = averageheight/#cells
	
	local std = 0
	for i = 1, #cells do
		local height = waveFunc(cells[i].site[1], cells[i].site[2])
		std = std + (height - averageheight)^2
	end
	std = sqrt(std/#cells)
	
	local waterFator = random()
	
	local bucketWidth = 80 + std/2
	local tierHeight = 110
	local tierConst = tierHeight + 45
	local tierMin, tierMax = 1000, -1000
	
	for i = 1, #cells do
		local cell = cells[i]
		local height = waveFunc(cell.site[1], cell.site[2])
		local tier = math.floor((height - averageheight + bucketWidth*waterFator)/bucketWidth)
		
		cell.tier = tier
		cell.height = tier*tierHeight + tierConst
		if cell.mirror then
			cell.mirror.tier = cell.tier
			cell.mirror.height = cell.height
		end
		
		tierMin = min(tier, tierMin)
		tierMax = max(tier, tierMax)
	end
	
	return tierConst, tierHeight, tierMin, tierMax
end

local function EstimateHeightDiff(mid, checkRadius, heights)
	local sampleCount = 25
	local heightSum = 0
	local maxHeight, minHeight
	for i = 1, sampleCount do
		local pos = GetRandomPointInCircle(mid, checkRadius, 50)
		local x, z = floor((pos[1] + 4)/8)*8, floor((pos[2] + 4)/8)*8
		
		local posHeight = heights[x][z]
		heightSum = heightSum + posHeight
		if (not minHeight) or (posHeight < minHeight) then
			minHeight = posHeight
		end
		if (not maxHeight) or (posHeight > maxHeight) then
			maxHeight = posHeight
		end
	end
	
	local heightAverage = heightSum/sampleCount
	--local cheapDeviation = min(maxHeight - heightAverage, heightAverage - minHeight)/(maxHeight - minHeight)
	return (maxHeight - minHeight)
end

local function SetStartCells(cells, edgesSorted, heights)
	local wantedFlatness = 80
	
	local startCell
	local minHeightDiff
	for i = 1, #edgesSorted do
		local thisEdge = edgesSorted[i]
		if #thisEdge.faces == 1 then
			local thisCell = thisEdge.faces[1]
			if thisCell.mirror and thisCell.tier >= -1 and (not thisCell.adjacentToCorner) then
				local heightDiff = EstimateHeightDiff(thisCell.averageMid, 700, heights)
				if (not minHeightDiff) or (heightDiff < minHeightDiff) then
					startCell = thisEdge.faces[1]
					minHeightDiff = heightDiff
				end
				if heightDiff < wantedFlatness then
					startCell = thisEdge.faces[1]
					if random() < 0.3 then
						break
					end
				end
			end
		end
	end
	
	return {startCell, startCell.mirror}
end

local function SetStatboxData(startCells)
	GG.mapgen_startBoxes = {}
	for i = 1, #startCells do
		local cell = startCells[i]
		GG.mapgen_startBoxes[#GG.mapgen_startBoxes + 1] = Spring.Utilities.CopyTable(cell.vertices)
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Metal Spots

local function EdgePassable(edge, needVeh, needBot, needLand)
	if needVeh and not edge.vehPass then
		return false
	end
	if needBot and not edge.botPass then
		return false
	end
	if needLand and not edge.landPass then
		return false
	end
	return true
end

local function GetPathDistances(cells, startCell, distName, needVeh, needBot, needLand)
	local seenCells = {}
	local checkCells = {}
	
	local checkIndex = 1
	local endIndex = 1
	
	seenCells[startCell.index] = true
	checkCells[checkIndex] = startCell
	startCell[distName] = 0
	
	while checkCells[checkIndex] do
		local thisCell = checkCells[checkIndex]
		local cellIndex = thisCell.index
		local edges = thisCell.edges
		for i = 1, #edges do
			local thisEdge = edges[i]
			local otherCell = thisEdge.otherFace[cellIndex]
			if otherCell and EdgePassable(thisEdge, needVeh, needBot, needLand) and not seenCells[otherCell.index] then
				otherCell[distName] = thisCell[distName] + 1
				endIndex = endIndex + 1
				checkCells[endIndex] = otherCell
				seenCells[otherCell.index] = true
			end
		end
		
		checkIndex = checkIndex + 1
	end
end

local function GetStraightDistances(cells, startCell, distName)
	local startSite = startCell.site
	for i = 1, #cells do
		local thisCell = cells[i]
		thisCell[distName] = Dist(thisCell.site, startSite)
	end
end

local function HasTierDiff(edge)
	return (edge.teirDiff ~= 0)
end

local function GetRandomMexPos(mexes, edges, pos, megaMex, placeRadius, maxRadius)
	local tries = 0
	local pointAvoid = 250
	local lineAvoid  = 300
	
	local randomPoint
	while tries < 50 do
		randomPoint = GetRandomPointInCircle(pos, placeRadius, 100)
		local _, lineDistSq = GetClosestLine(randomPoint, edges, HasTierDiff)
		if (not lineDistSq) or (lineAvoid^2 < lineDistSq) then
			local _, pointDist = GetClosestPoint(randomPoint, mexes)
			if (not pointDist) or (pointAvoid < pointDist) then
				return randomPoint
			end
		end
		pointAvoid  = max(pointAvoid  - 10, 150)
		lineAvoid   = max(lineAvoid   - 20, 20)
		placeRadius = min(placeRadius + 20, maxRadius)
		
		tries = tries + 1
	end
	
	PointEcho(randomPoint, "FAILED")
	
	return false
end

local function PlaceMex(mexes, edges, pos, megaMex)
	local mexPos = GetRandomMexPos(mexes, edges, pos, megaMex, (megaMex and 50) or 450, (megaMex and 300) or 450)
	if not mexPos then
		return
	end
	local mirrorMexPos = ApplyRotSymmetry(mexPos)
	local mexValue = ((megaMex and 4) or 2)
	
	if Dist(mexPos, mirrorMexPos) > 120 then
		mexes[#mexes + 1] = mexPos
		mexes[#mexes + 1] = mirrorMexPos
		
		GG.mapgen_mexList = GG.mapgen_mexList or {}
		GG.mapgen_mexList[#GG.mapgen_mexList + 1] = {x = mexPos[1], z = mexPos[2], metal = mexValue}
		GG.mapgen_mexList[#GG.mapgen_mexList + 1] = {x = mirrorMexPos[1], z = mirrorMexPos[2], metal = mexValue}
	else
		mexPos = {MID_X, MID_Z}
		mexes[#mexes + 1] = mexPos
		GG.mapgen_mexList = GG.mapgen_mexList or {}
		GG.mapgen_mexList[#GG.mapgen_mexList + 1] = {x = mexPos[1], z = mexPos[2], metal = mexValue}
	end
end

local function ReduceMexAllocation(cell, totalMexAlloc, allocFactor)
	cell = (cell.firstMirror and cell) or cell.mirror
	local allocChange = (cell.mexAlloc or 0)*(1 - allocFactor)
	cell.mexAlloc = cell.mexAlloc and (cell.mexAlloc - allocChange)
	return totalMexAlloc - allocChange
end

local function GetMetalValues(cells, edges, startCells)
	local startCell = startCells[1]
	
	GetPathDistances(cells, startCell, "landBotDist", false, true, true)
	GetStraightDistances(cells, startCell, "straightDist")
	local minPathDiff, maxPathDiff
	local minDistSum, maxDistSum
	for i = 1, #cells do
		local thisCell = cells[i]
		local mirror = thisCell.mirror
		if mirror then
			if thisCell.landBotDist and mirror.landBotDist then
				local pathDiff = abs(thisCell.landBotDist - mirror.landBotDist)
				if (not minPathDiff) or (pathDiff < minPathDiff) then
					minPathDiff = pathDiff
				end
				if (not maxPathDiff) or (pathDiff > maxPathDiff) then
					maxPathDiff = pathDiff
				end
			end
			if thisCell.straightDist and mirror.straightDist then
				local distSum = thisCell.straightDist + mirror.straightDist
				if (not minDistSum) or (distSum < minDistSum) then
					minDistSum = distSum
				end
				if (not maxDistSum) or (distSum > maxDistSum) then
					maxDistSum = distSum
				end
			end
		end
	end
	
	if not minPathDiff then
		minPathDiff = 0
	end
	if (not maxPathDiff) or (maxPathDiff == minPathDiff) then
		maxPathDiff = minPathDiff + 1
	end
	if not minDistSum then
		minDistSum = 3000
	end
	if not maxDistSum then
		maxDistSum = 6000
	end
	
	local totalMexAlloc = 0
	for i = 1, #cells do
		local thisCell = cells[i]
		if thisCell.firstMirror then
			local mirror = thisCell.mirror
			local minBotDist = false
			
			if thisCell.landBotDist and mirror and mirror.landBotDist then
				thisCell.startPathFactor = (abs(thisCell.landBotDist - mirror.landBotDist) - minPathDiff)/(maxPathDiff - minPathDiff)
				minBotDist = min(thisCell.landBotDist, (mirror and mirror.landBotDist) or mirror.landBotDist)
			else
				thisCell.startPathFactor = 0
			end
			
			if thisCell.straightDist and mirror and mirror.straightDist then
				thisCell.startDistFactor = (thisCell.straightDist + mirror.straightDist - minDistSum)/(maxDistSum - minDistSum)
			else
				thisCell.startDistFactor = 0
			end
			
			if (thisCell.landBotDist == 0) or (mirror and (mirror.landBotDist == 0)) then
				thisCell.metalSpots = 3
			else
				thisCell.mexAlloc = thisCell.startPathFactor*1.5 + thisCell.startDistFactor*1.2 + 0.2
				if minBotDist == 1 then
					thisCell.mexAlloc = max(0, thisCell.mexAlloc - 0.4)
				end
				if thisCell.adjacentToBorder then
					thisCell.mexAlloc = thisCell.mexAlloc + 0.15
				end
				if thisCell.adjacentToCorner then
					thisCell.mexAlloc = thisCell.mexAlloc + 0.35
				end
				
				if not minBotDist then
					thisCell.mexAlloc = thisCell.mexAlloc*0.18
				end
				totalMexAlloc = totalMexAlloc + thisCell.mexAlloc
			end
		end
	end
	
	local mexSpots = random(7, 12)
	while mexSpots > 0 do
		local mexCell = cells[random(1, #cells)]
		local randAllocateSum = random()*totalMexAlloc
		for i = 1, #cells do
			local thisCell = cells[i]
			if thisCell.mexAlloc and (randAllocateSum < thisCell.mexAlloc) then
				mexCell = thisCell
				break
			else
				randAllocateSum = randAllocateSum - (thisCell.mexAlloc or 0)
			end
		end
		
		local allocChange = mexCell.mexAlloc or 0
		local mexAssignment = (((random() < 0.35) and 2) or 1)
		if mexCell.adjacentToMirror then
			mexAssignment = 1
		end
		
		if (mexCell.startPathFactor == 0) and ((not mexCell.mirror) or Dist(mexCell.averageMid, mexCell.mirror.averageMid) > 1200) then
			if mexCell.mexAlloc and (random() < mexCell.mexAlloc/2) then
				mexCell.megaMex = true
				mexAssignment = 2
			end
		end
		
		totalMexAlloc = ReduceMexAllocation(mexCell, totalMexAlloc, 0)
		local neighbourFactor = (((mexAssignment == 2) and 0.01) or 0.25)
		for i = 1, #mexCell.neighbours do
			totalMexAlloc = ReduceMexAllocation(mexCell.neighbours[i], totalMexAlloc, neighbourFactor)
		end
		mexCell.metalSpots = (mexCell.metalSpots or 0) + mexAssignment
		
		mexSpots = mexSpots - mexAssignment
	end
	
	local mexes = {}
	for i = 1, #cells do
		local thisCell = cells[i]
		if thisCell.firstMirror then
			if thisCell.megaMex then
				PlaceMex(mexes, thisCell.edges, thisCell.averageMid, true)
			elseif thisCell.metalSpots then
				for j = 1, thisCell.metalSpots do
					PlaceMex(mexes, thisCell.edges, thisCell.averageMid, false)
				end
			end
		end
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Callins

-- Gameframe draw debug
local toDrawEdges = nil
local waitCount = 0

local function GetSeed()
	local mapOpts = Spring.GetMapOptions()
	if mapOpts and mapOpts.seed and tonumber(mapOpts.seed) ~= 0 then
		return tonumber(mapOpts.seed)
	end
	
	local modOpts = Spring.GetModOptions()
	if modOpts and modOpts.mapgen_seed and tonumber(modOpts.mapgen_seed) ~= 0 then
		return tonumber(modOpts.mapgen_seed)
	end
	
	return random(1, 100000)
end

function gadget:Initialize()
	local randomSeed = GetSeed()
	-- 84989
	-- 9661
	-- 74370
	-- 29669
	-- 9498
	-- 93286 flat map
	-- 34349 blocked map, broken floodfill
	math.randomseed(randomSeed)

	Spring.SetGameRulesParam("typemap", "temperate")
	Spring.SetGameRulesParam("mapgen_enabled", 1)
	
	TimerEcho("Map Terrain Generation")
	Spring.Echo("Random Seed", randomSeed)
	local waveFunc = GetTerrainWaveFunction()
	--TerraformByFunc(waveFunc)
	TimerEcho("Wave generation complete")
	
	local cells, edges = GetVoronoi(18, 400, 500)
	toDrawEdges = edges
	TimerEcho("Voronoi generation complete")
	
	local edgesSorted = Spring.Utilities.CopyTable(edges, false)
	table.sort(edgesSorted, CompareLength)
	
	local tierConst, tierHeight, tierMin, tierMax = GenerateCellTiers(cells, waveFunc)
	GenerateEdgePassability(edgesSorted)
	TimerEcho("Tier generation complete")
	
	local tierFlood, heightMod = ProcessEdges(cells, edges)
	TimerEcho("Edge terrain complete")
	
	local tiers = tierFlood.RunFloodfillAndGetValues()
	TimerEcho("Floodfill complete")
	
	local heights = ApplyHeightModifiers(tierConst, tierHeight, tierMin, tierMax, tiers, heightMod, waveFunc, 0.2)
	TimerEcho("Height application complete")
	
	--local smoothFilter = {
	--	{0, 0, 1},
	--	{8, 0, 0.9},
	--	{-8, 0, 0.9},
	--	{0, 8, 0.9},
	--	{0, -8, 0.9},
	--	{8, 8, 0.63},
	--	{8, -8, 0.63},
	--	{-8, 8, 0.63},
	--	{-8, -8, 0.63},
	--	{16, 0, 0.45},
	--	{-16, 0, 0.45},
	--	{0, 16, 0.45},
	--	{0, -16, 0.45},
	--}
	local smoothFilter = {
		{0, 0, 1},
		{8, 0, 1},
		{-8, 0, 1},
		{0, 8, 1},
		{0, -8, 1},
		{8, 8, 0.9},
		{8, -8, 0.9},
		{-8, 8, 0.9},
		{-8, -8, 0.9},
		{16, 0, 0.65},
		{-16, 0, 0.65},
		{0, 16, 0.65},
		{0, -16, 0.65},
	}
	
	local smoothHeights = ApplyHeightSmooth(heights, smoothFilter)
	TimerEcho("Smoothing complete")
	
	startCells = SetStartCells(cells, edgesSorted, heights)
	SetStatboxData(startCells)
	
	local metalValues = GetMetalValues(cells, edges, startCells)
	TimerEcho("Metal generation complete")
	
	TerraformByHeights(smoothHeights)
	GG.mapgen_origHeight = smoothHeights
	TimerEcho("Map terrain generation complete")
end

function gadget:GameFrame()
	if not toDrawEdges then
		return
	end
	
	waitCount = (waitCount or 0) + 1
	if waitCount < 40 then
		return
	end
	
	for i = 1, #toDrawEdges do
		local edge = toDrawEdges[i]
		LineDraw(edge)
		--LineEcho(edge, MakeBoolString({edge.vehPass, edge.botPass, edge.landPass}) .. ", width: " .. edge.terrainWidth .. ", tier: " .. edge.teirDiff)
	end
	
	toDrawEdges = nil
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Debug

local timer
function TimerEcho(text)
	if not timer then
		--timer = Spring.GetTimer()
		Spring.Echo(text)
		return
	end
	--local cur = Spring.GetTimer()
	--Spring.Echo(Spring.DiffTimers(cur, timer, true), text)
	--timer = cur
end

function PointEcho(point, text)
	Spring.MarkerAddPoint(point[1], 0, point[2], text or "")
end

function LineEcho(p1, p2, text)
	if text then
		PointEcho(GetMidpoint(p1, p2), text)
	else
		PointEcho(GetMidpoint(p1[1], p1[2]), p2)
	end
end

function LineDraw(p1, p2)
	if p2 then
		Spring.MarkerAddLine(p1[1], 0, p1[2], p2[1], 0, p2[2], true)
	else
		Spring.MarkerAddLine(p1[1][1], 0, p1[1][2], p1[2][1], 0, p1[2][2], true)
		Spring.MarkerAddLine(p1[2][1] + 20, 0, p1[2][2], p1[2][1] - 20, 0, p1[2][2], true)
		Spring.MarkerAddLine(p1[2][1], 0, p1[2][2] + 20, p1[2][1], 0, p1[2][2] - 20, true)
	end
end

function CellEcho(cell)
	PointEcho(cell.site, "Cell: " .. cell.index .. ", edges: " .. #cell.edges)
	for k = 1, #cell.edges do
		LineDraw(cell.edges[k])
	end
end

function MakeBoolString(values)
	local str = " "
	for i = 1, #values do
		str = str .. ((values[i] and 1) or 0)
	end
	return str
end

function IsDebugCoord(x, z)
	return abs(x - 5464) <= 4 and abs(z - 4168) <= 4
end
