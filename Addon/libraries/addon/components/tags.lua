-- required libraries
require("libraries.addon.script.debugging")

-- library name
Tags = {}

--- Checks if a tag exists in a table of tags
--- @param tags table<number, string> a table of tags to search through
--- @param tag string the tag to search for
--- @param decrement boolean|nil whether to search from the end of the table to the start
--- @return boolean has_tag whether the tag was found
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

--- gets the value of the specifed tag, returns nil if tag not found. 
--- Note: **By default it uses tonumber()** on the value, so remember to set the as_string parameter to true if you are getting text
--- @param tags table<number, string> a table of tags to search through
--- @param tag string the tag to search for
--- @param as_string boolean? whether to return the value as a string instead of a number
--- @overload fun(tags: table<number, string>, tag: string, as_string: true): string?
--- @return number? value the value of the tag, nil if not found
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