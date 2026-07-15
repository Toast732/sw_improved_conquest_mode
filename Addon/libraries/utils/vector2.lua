--[[
	
Copyright 2025 Liam Matthews

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

	http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

]]

-- Library Version 0.0.3

--[[


	Library Setup


]]

-- required libraries

---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field

--[[ 
	Contains some code for math on Vector 2s, as in, a 2D vector.
]]

-- library name
Vector2 = {}

--[[


	Classes


]]

---@class Vector2
---@field x number
---@field y number Usually the z axis in disguise.

--[[


	Variables


]]

--[[


	Functions


]]

--- Function for creating a new Vector2
---@param x number
---@param y number
---@return Vector2
function Vector2.new(x, y)
	-- create the vector
	local vector = {
		x = x,
		y = y
	}

	-- return the vector
	return vector
end

--- Function for turning a Matrix into a Vector2 (matrix x becomes vector x, matrix z becomes vector y)
---@param target_matrix SWMatrix
---@param raw_coordinates boolean? whether or not to return the raw coordinates of the matrix (true), or the transformed coordinates (false/nil).
---@return Vector2 vector the vector created from the matrix.
function Vector2.fromMatrix(target_matrix, raw_coordinates)
	-- if raw_coordinates is true
	if raw_coordinates then
		-- return the raw coordinates
		return {
			x = target_matrix[13],
			y = target_matrix[15]
		}
	end

	--* raw coordinates is false, return the transformed coordinates

	-- get transformed coordinates (I assume this function properly applies the rotations, scaling, etc to the matrix.)
	local x, _, z = matrix.position(target_matrix)

	-- return the transformed coordinates
	return {
		x = x,
		y = z
	}
end

--- Function for creating a Vector2 from polar coordinates
---@param distance number the distance from the origin
---@param angle number the angle from the origin
---@return Vector2
function Vector2.fromPolar(distance, angle)
	-- create the vector from the polar coordinates
	local vector = {
		x = distance * math.cos(angle),
		y = distance * math.sin(angle)
	}

	-- return the vector
	return vector
end

--- Function for adding two Vector2s
---@param a Vector2
---@param b Vector2
---@return Vector2
function Vector2.add(a, b)
	-- create the added vector
	local vector = {
		x = a.x + b.x,
		y = a.y + b.y
	}

	-- return the vector
	return vector
end

--- Function for getting the euclidean distance
---@param a Vector2
---@param b Vector2
---@return number euclidean_distance euclidean distance between the two 2D vectors.
function Vector2.euclideanDistance(a, b)
	-- get the relative x position
	local rx = a.x - b.x

	-- get the relative y position
	local ry = a.y - b.y

	-- return the distance
	return math.sqrt(rx*rx+ry*ry)
end

--- Function for getting the manhattan distance
---@param a Vector2
---@param b Vector2
---@return number manhattan_distance manhattan distance between the two 2D vectors.
function Vector2.manhattanDistance(a, b)
	-- return the distance
	return (
		math.abs(a.x - b.x) + -- get manhattan distance on x axis
		math.abs(a.y - b.y) -- get manhattan distance on y axis
	)
end

--- Function for getting the angle from vector a to vector b
---@param a Vector2
---@param b Vector2
---@return number angle the angle from vector a to vector b
function Vector2.angleBetween(a, b)
	-- get the relative x position
	local rx = b.x - a.x

	-- get the relative y position
	local ry = b.y - a.y

	-- return the angle
	return math.atan(rx, ry)
end

--- Function for adding two Vector2s.
---@param a Vector2 the first vector to add.
---@param b Vector2 the second vector to add.
---@return Vector2 added_vector the vector created from the addition of the two vectors.
function Vector2.add(a, b)
	-- create the vector
	local added_vector = {
		x = a.x + b.x,
		y = a.y + b.y
	}

	-- return the vector
	return added_vector
end

--- Function for subtracting two Vector2s.
---@param a Vector2 the vector to subtract from.
---@param b Vector2 the vector to subtract.
---@return Vector2 subtracted_vector the vector created from the subtraction of the two vectors.
function Vector2.subtract(a, b)
	-- create the vector
	local subtracted_vector = {
		x = a.x - b.x,
		y = a.y - b.y
	}

	-- return the vector
	return subtracted_vector
end

--- Function for multiplying two Vector2s.
---@param a Vector2 the first vector to multiply.
---@param b Vector2 the second vector to multiply.
---@return Vector2 multiplied_vector the vector created from the multiplication of the two vectors.
function Vector2.multiply(a, b)
	-- create the vector
	local multiplied_vector = {
		x = a.x * b.x,
		y = a.y * b.y
	}

	-- return the vector
	return multiplied_vector
end

--- Function for dividing two Vector2s.
---@param a Vector2 the vector to divide.
---@param b Vector2 the vector to divide by.
---@return Vector2 divided_vector the vector created from the division of the two vectors.
function Vector2.divide(a, b)
	-- create the vector
	local divided_vector = {
		x = a.x / b.x,
		y = a.y / b.y
	}

	-- return the vector
	return divided_vector
end

--- Function for doing a scalar division on a vector.
---@param vector Vector2 the vector to divide.
---@param scalar number the scalar to divide the vector by.
---@return Vector2 divided_vector the vector created from the division of the vector by the scalar.
function Vector2.scalarDivide(vector, scalar)
	-- create the vector
	local divided_vector = {
		x = vector.x / scalar,
		y = vector.y / scalar
	}

	-- return the vector
	return divided_vector
end

--- Function for doing a scalar multiplication on a vector.
---@param vector Vector2 the vector to multiply.
---@param scalar number the scalar to multiply the vector by.
---@return Vector2 multiplied_vector the vector created from the multiplication of the vector by the scalar.
function Vector2.scalarMultiply(vector, scalar)
	-- create the vector
	local multiplied_vector = {
		x = vector.x * scalar,
		y = vector.y * scalar
	}

	-- return the vector
	return multiplied_vector
end

--- Function for doing a dot product on two vectors.
---@param a Vector2 the first vector to use in the dot product
---@param b Vector2 the second vector to use in the dot product
---@return number dot_product the dot product of the two vectors.
function Vector2.dotProduct(a, b)
	-- Calculate and Return the dot product.
	return (
		a.x * b.x
		+ a.y * b.y
	)
end

--- Function for getting the length of a vector
---@param vector Vector2 the vector to get the length of
---@return number length the length of the vector
function Vector2.length(vector)
	return math.sqrt(
		vector.x * vector.x
		+ vector.y * vector.y
	)
end

--- Function for normalising a vector.
---@param vector Vector2 the vector to normalise.
---@return Vector2 normalised_vector the normalised vector
function Vector2.normalise(vector)
	-- Get the length of the vector
	local vector_length = Vector2.length(vector)

	-- Do and return a scalar division on the vector by the vector length.
	return Vector2.scalarDivide(vector, vector_length)
end

--- Function for doing a scalar projection on a Vector2. Projects position onto a line defined by line_start and line_end, for a given maximum distance.
---@param position Vector2 the position to project onto the line.
---@param line_start Vector2 the start position of the line.
---@param line_end Vector2 the end position of the line.
---@param maximum_distance number the maximum projection distance.
---@return Vector2 projected_vector the vector projected onto the line.
---@return number projected_distance the distance the vector was projected forward by.
function Vector2.scalarProjection(position, line_start, line_end, maximum_distance)
	-- Get the position local to the line start
	local position_vector = Vector2.subtract(position, line_start)

	-- Get the line end position local to the line start
	local line_vector = Vector2.subtract(line_end, line_start)

	-- Get a normalised version of the line vector.
	local line_vector_normalised = Vector2.normalise(line_vector)

	-- Get the length of the line vector
	local line_vector_length = Vector2.length(line_vector)

	-- Get the progress of the position along the line vector.
	local position_progress =Vector2.dotProduct( -- Get the dot product
		position_vector,
		line_vector
	) / line_vector_length -- Divide by the length of the vector.

	-- Get the position as if it was on the path.
	local position_on_path = Vector2.add( -- Add the line start and normalised line vector vectors together.
		line_start,
		Vector2.scalarMultiply(
			line_vector_normalised,
			position_progress -- Scalar Multiply by where the position would be if it was along the line.
		)
	)

	-- Calculate the projection distance, by capping it to the line's end.
	local projection_distance = math.min(
		Vector2.euclideanDistance(
			line_end,
			position_on_path
		),
		maximum_distance
	)

	-- Calculate the projected vector
	local projected_vector = Vector2.add( -- Add the line start and normalised line vector vectors together.
		line_start,
		Vector2.scalarMultiply(
			line_vector_normalised,
			position_progress + projection_distance -- Scalar Multiply by the projection distance
		)
	)

	-- Return the projected vector.
	return projected_vector, projection_distance
end

--- Function for linearly interpolating between two Vector2s.
---@param source Vector2 the position to interpolate from.
---@param target Vector2 the position to interpolate to.
---@param alpha number the alpha value to interpolate by. (0 being source, 1 being target, 0.5 being halfway between source and target, though, not limited to 0-1.)
---@return Vector2 interpolated_vector the vector created from the interpolation of the two vectors.
function Vector2.lerp(source, target, alpha)
	-- Get the inverted alpha for multiplying the source.
	local inverted_alpha = 1 - alpha

	-- Create the vector
	local interpolated_vector = Vector2.add(
		Vector2.scalarMultiply(source, inverted_alpha),
		Vector2.scalarMultiply(target, alpha)
	)

	-- Return the vector
	return interpolated_vector
end