-- required libraries
require("libraries.debugging")
require("libraries.math")

-- library name
Map = {}

--# draws a search area within the specified radius at the coordinates provided
---@param x number the x coordinate of where the search area will be drawn around (required)
---@param z number the z coordinate of where the search area will be drawn around (required)
---@param radius number the radius of the search area (required)
---@param ui_id integer the ui_id of the search area (required)
---@param peer_id integer the peer_id of the player which you want to draw the search area for (defaults to -1)
---@param label string The text that appears when mousing over the icon. Appears like a title (defaults to "")
---@param hover_label string The text that appears when mousing over the icon. Appears like a subtitle or description (defaults to "")
---@param r integer 0-255, the red value of the search area (defaults to 255)
---@param g integer 0-255, the green value of the search area (defaults to 255)
---@param b integer 0-255, the blue value of the search area (defaults to 255)
---@param a integer 0-255, the alpha value of the search area (defaults to 255)
---@return number x the x coordinate of where the search area was drawn
---@return number z the z coordinate of where the search area was drawn
---@return boolean success if the search area was drawn
function Map.drawSearchArea(x, z, radius, ui_id, peer_id, label, hover_label, r, g, b, a)

	if not x then -- if the x position of the target was not provided
		d.print("(Map.drawSearchArea) x is nil!", true, 1)
		return nil, nil, false
	end

	if not z then -- if the z position of the target was not provided
		d.print("(Map.drawSearchArea) z is nil!", true, 1)
		return nil, nil, false
	end

	if not radius then -- if the radius of the search area was not provided
		d.print("(Map.drawSearchArea) radius is nil!", true, 1)
		return nil, nil, false
	end

	if not ui_id then -- if the ui_id was not provided
		d.print("(Map.drawSearchArea) ui_id is nil!", true, 1)
		return nil, nil, false
	end

	-- default values (if not specified)

	local peer_id = peer_id or -1 -- makes the peer_id default to -1 if not provided (-1 = everybody)

	local label = label or "" -- defaults the label to "" if it was not specified
	local hover_label = hover_label or "" -- defaults the hover_label to "" if it was not specified

	local r = r or 255 -- makes the red colour default to 255 if not provided
	local g = g or 255 -- makes the green colour default to 255 if not provided
	local b = b or 255 -- makes the blue colour default to 255 if not provided
	local a = a or 255 -- makes the alpha default to 255 if not provided

	local angle = math.random() * math.pi * 2 -- gets a random angle to put the search radius focus around
	local dist = math.sqrt(math.randomDecimals(0.1, 0.9)) * radius -- gets a random distance from the target to put the search radius at

	local x_pos = dist * math.sin(angle) + x -- uses the distance and angle to make the x pos of the search radius
	local z_pos = dist * math.cos(angle) + z -- uses the distance and angle to make the z pos of the search radius

	s.addMapObject(peer_id, ui_id, 0, 2, x_pos, z_pos, 0, 0, 0, 0, label, radius, hover_label, r, g, b, a) -- draws the search radius to the map

	return x_pos, z_pos, true -- returns the x pos and z pos of the drawn search radius, and returns true that it was drawn.
end

function Map.addMapCircle(peer_id, ui_id, center_matrix, radius, width, r, g, b, a, lines) -- credit to woe
	peer_id, ui_id, center_matrix, radius, width, r, g, b, a, lines = peer_id or -1, ui_id or 0, center_matrix or m.translation(0, 0, 0), radius or 500, width or 0.25, r or 255, g or 0, b or 0, a or 255, lines or 16
	local center_x, center_z, tau = center_matrix[13], center_matrix[15], math.pi*2
	for i = 0, lines do
		local x1, z1 = center_x+radius*math.cos(tau/lines*i), center_z+radius*math.sin(tau/lines*i)
		local x2, z2 = center_x+radius*math.cos(tau/lines*(i+1)), center_z+radius*math.sin(tau/lines*(i+1))
		local start_matrix, end_matrix = m.translation(x1, 0, z1), m.translation(x2, 0, z2)
		s.addMapLine(peer_id, ui_id, start_matrix, end_matrix, width, r, g, b, a)
	end
end