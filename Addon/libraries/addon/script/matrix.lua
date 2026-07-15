require("libraries.utils.math")

---@param matrix1 SWMatrix the first matrix
---@param matrix2 SWMatrix the second matrix
---@return number distance the xz distance between the two matrices
function matrix.xzDistance(matrix1, matrix2) -- returns the euclidean distance between two matrixes, ignoring the y axis
	return math.euclideanDistance(matrix1[13], matrix2[13], matrix1[15], matrix2[15])
end

---@param rot_matrix SWMatrix the matrix you want to get the rotation of
---@return number x_axis the x_axis rotation (roll)
---@return number y_axis the y_axis rotation (yaw)
---@return number z_axis the z_axis rotation (pitch)
function matrix.getMatrixRotation(rot_matrix) --returns radians for the functions: matrix.rotation X and Y and Z (credit to woe and quale)
	local z = -math.atan(rot_matrix[5],rot_matrix[1])
	rot_matrix = matrix.multiply(rot_matrix, matrix.rotationZ(-z))
	return math.atan(rot_matrix[7],rot_matrix[6]), math.atan(rot_matrix[9],rot_matrix[11]), z
end

---@param matrix1 SWMatrix the first matrix
---@param matrix2 SWMatrix the second matrix
---@return SWMatrix matrix the multiplied matrix
function matrix.multiplyXZ(matrix1, matrix2)
	local matrix3 = {table.unpack(matrix1)}
	matrix3[13] = matrix3[13] + matrix2[13]
	matrix3[15] = matrix3[15] + matrix2[15]
	return matrix3
end

--# returns the total velocity (m/s) between the two matrices
---@param matrix1 SWMatrix the first matrix
---@param matrix2 SWMatrix the second matrix
---@param ticks_between number the ticks between the two matrices
---@return number velocity the total velocity
function matrix.velocity(matrix1, matrix2, ticks_between)
	ticks_between = ticks_between or 1
	-- total velocity
	return math.euclideanDistance(matrix1[13], matrix2[13], matrix1[15], matrix2[15], matrix1[14], matrix2[14]) * 60/ticks_between
end

--# returns the acceleration, given 3 matrices. Each matrix must be the same ticks between eachother.
---@param matrix1 SWMatrix the most recent matrix
---@param matrix2 SWMatrix the second most recent matrix
---@param matrix3 SWMatrix the third most recent matrix
---@return number acceleration the acceleration in m/s
function matrix.acceleration(matrix1, matrix2, matrix3, ticks_between)
	local v1 = matrix.velocity(matrix1, matrix2, ticks_between) -- last change in velocity
	local v2 = matrix.velocity(matrix2, matrix3, ticks_between) -- change in velocity from ticks_between ago
	-- returns the acceleration
	return (v1-v2)/(ticks_between/60)
end

function matrix.clone(matrix_to_clone)
	return {
		matrix_to_clone[1],
		matrix_to_clone[2],
		matrix_to_clone[3],
		matrix_to_clone[4],
		matrix_to_clone[5],
		matrix_to_clone[6],
		matrix_to_clone[7],
		matrix_to_clone[8],
		matrix_to_clone[9],
		matrix_to_clone[10],
		matrix_to_clone[11],
		matrix_to_clone[12],
		matrix_to_clone[13],
		matrix_to_clone[14],
		matrix_to_clone[15],
		matrix_to_clone[16]
	}
end

--- Returns true if the two matrixes match on all params.
---@param m1 SWMatrix the first matrix
---@param m2 SWMatrix the second matrix
---@return boolean is_equal true if the matrixes are equal
function matrix.equals(m1, m2)
	return
		m1[1] == m2[1] and
		m1[2] == m2[2] and
		m1[3] == m2[3] and
		m1[4] == m2[4] and
		m1[5] == m2[5] and
		m1[6] == m2[6] and
		m1[7] == m2[7] and
		m1[8] == m2[8] and
		m1[9] == m2[9] and
		m1[10] == m2[10] and
		m1[11] == m2[11] and
		m1[12] == m2[12] and
		m1[13] == m2[13] and
		m1[14] == m2[14] and
		m1[15] == m2[15] and
		m1[16] == m2[16]
end

--- Returns true if the two matrixes match on all params. Meant to be used when it's been stored in g_savedata, as this will remove to the last decimal point. on [13], [14], and [15]
---@param m1 SWMatrix the first matrix
---@param m2 SWMatrix the second matrix
---@return boolean is_equal true if the matrixes are equal
function matrix.g_equals(m1, m2)
	-- Most params are just ==, but for 13, 14, and 15, we want to remove to the last decimal for comparison, due to the strange compression/randomisation on the location params.
	return
		m1[1] == m2[1] and
		m1[2] == m2[2] and
		m1[3] == m2[3] and
		m1[4] == m2[4] and
		m1[5] == m2[5] and
		m1[6] == m2[6] and
		m1[7] == m2[7] and
		m1[8] == m2[8] and
		m1[9] == m2[9] and
		m1[10] == m2[10] and
		m1[11] == m2[11] and
		m1[12] == m2[12] and
		math.round(m1[13], 0) == math.round(m2[13], 0) and
		math.round(m1[14], 0) == math.round(m2[14], 0) and
		math.round(m1[15], 0) == math.round(m2[15], 0) and
		m1[16] == m2[16]
		
end