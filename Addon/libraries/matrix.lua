---@param matrix1 SWMatrix the first matrix
---@param matrix2 SWMatrix the second matrix
function matrix.xzDistance(matrix1, matrix2) -- returns the distance between two matrixes, ignoring the y axis
	local ox, oy, oz = m.position(matrix1)
	local tx, ty, tz = m.position(matrix2)
	return m.distance(m.translation(ox, 0, oz), m.translation(tx, 0, tz))
end

---@param rot_matrix SWMatrix the matrix you want to get the rotation of
---@return number x_axis the x_axis rotation (roll)
---@return number y_axis the y_axis rotation (yaw)
---@return number z_axis the z_axis rotation (pitch)
function matrix.getMatrixRotation(rot_matrix) --returns radians for the functions: matrix.rotation X and Y and Z (credit to woe and quale)
	local z = -math.atan(rot_matrix[5],rot_matrix[1])
	rot_matrix = m.multiply(rot_matrix, m.rotationZ(-z))
	return math.atan(rot_matrix[7],rot_matrix[6]), math.atan(rot_matrix[9],rot_matrix[11]), z
end