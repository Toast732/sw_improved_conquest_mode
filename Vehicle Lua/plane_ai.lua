local tau = math.pi*2
local half_pi = math.pi*0.5

function getAngle(tx, tz, px, pz)
	return math.atan(tx - px, tz - pz)
end

local roll_sensitivity = property.getNumber("Roll Sensitivity")

function onTick()
	local x = input.getNumber(1)
	local y = input.getNumber(2)
	local z = input.getNumber(3)

	local tx = input.getNumber(13)
	local ty = input.getNumber(14)
	local tz = input.getNumber(15)

	local roll = input.getNumber(8)

	local roll_target = getAngle(x, z, tx, tz)/half_pi

	local roll_output = (roll-roll_target)*roll_sensitivity

	-- left wing
	output.setNumber(1, roll_output)

	-- right wing
	output.setNumber(2, -roll_output)
end