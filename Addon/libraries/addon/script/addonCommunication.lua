--[[


	Library Setup


]]

-- required libraries
require("libraries.addon.script.debugging")

-- library name
AddonCommunication = {}

-- shortened library name
ac = AddonCommunication

--[[


	Variables
   

]]

replies_awaiting = {}

--[[


	Classes


]]

--[[


	Functions         


]]

function AddonCommunication.executeOnReply(short_addon_name, message, port, execute_function, count, timeout)
	short_addon_name = short_addon_name or SHORT_ADDON_NAME-- default to this addon's short name
	if not message then
		d.print("(AddonCommunication.executeOnReply) message was left blank!", true, 1)
		return
	end

	port = port or 0

	if not execute_function then
		d.print("(AddonCommunication.executeOnReply) execute_function was left blank!", true, 1)
		return
	end

	count = count or 1

	timeout = timeout or -1

	local expiry = -1
	if timeout ~= -1 then
		expiry = s.getTimeMillisec() + timeout*60
	end

	table.insert(replies_awaiting, {
		short_addon_name = short_addon_name,
		message = message,
		port = port,
		execute_function = execute_function,
		count = count,
		expiry = expiry
	})
end

function AddonCommunication.tick()
	for reply_index, reply in ipairs(replies_awaiting) do
		-- check if this reply has expired
		if reply.expiry ~= -1 and s.getTimeMillisec() > reply.expiry then
			-- it has expired
			d.print(("A function awaiting a reply of %s from %s has expired."):format(reply.message, reply.short_addon_name), true, 0)
			table.remove(replies_awaiting, reply_index)
		end
	end
end

function AddonCommunication.sendCommunication(message, port)
	if not message then
		d.print("(AddonCommunication.sendCommunication) message was left blank!", true, 1)
		return
	end

	port = port or 0

	-- add this addon's short name to the list
	local prepared_message = ("%s:%s"):format(SHORT_ADDON_NAME, message)

	-- send the message
	s.httpGet(port, prepared_message)
end

function httpReply(port, message)
	-- check if we're waiting to execute a function from this reply
	for reply_index, reply in ipairs(replies_awaiting) do
		-- check if this is the same port
		if reply.port ~= port then
			goto httpReply_continue_reply
		end

		-- check if the message content is the one we're looking for
		if ("%s:%s"):format(reply.short_addon_name, reply.message) ~= message then
			goto httpReply_continue_reply
		end

		-- this is the one we're looking for!

		-- remove 1 from count
		reply.count = math.max(reply.count - 1, -1)

		-- execute the function
		reply:execute_function()

		-- if count == 0 then remove this from the replies awaiting
		if reply.count == 0 then
			table.remove(replies_awaiting, reply_index)
		end

		break

		::httpReply_continue_reply::
	end
end