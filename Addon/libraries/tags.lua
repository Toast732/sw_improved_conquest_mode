-- required libraries
require("libraries.debugging")

-- library name
Tags = {}

function Tags.has(tags, tag, decrement)
	if type(tags) ~= "table" then
		d.print("(Tags.has) was expecting a table, but got a "..type(tags).." instead! searching for tag: "..tag.." (this can be safely ignored)", true, 1)
		return false
	end

	if not decrement then
		for tag_index = 1, #tags do
			if tags[tag_index] == tag then
				return true
			end
		end
	else
		for tag_index = #tags, 1, -1 do
			if tags[tag_index] == tag then
				return true
			end 
		end
	end

	return false
end

-- gets the value of the specifed tag, returns nil if tag not found
function Tags.getValue(tags, tag, as_string)
	if type(tags) ~= "table" then
		d.print("(Tags.getValue) was expecting a table, but got a "..type(tags).." instead! searching for tag: "..tag.." (this can be safely ignored)", true, 1)
	end

	for k, v in pairs(tags) do
		if string.match(v, tag.."=") then
			if not as_string then
				return tonumber(tostring(string.gsub(v, tag.."=", "")))
			else
				return tostring(string.gsub(v, tag.."=", ""))
			end
		end
	end
	
	return nil
end