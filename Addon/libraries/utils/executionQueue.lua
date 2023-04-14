--[[


	Library Setup


]]

-- required libraries
require("libraries.addon.script.debugging")

-- library name
ExecutionQueue = {}

-- shortened library name
eq = ExecutionQueue

--[[


	Variables
   

]]

s = s or server

queued_executions = {}

--[[


	Classes


]]

--[[


	Functions


]]

---# print function just in case debugging.lua is not present.
---@param message string the message you want to print
---@param requires_debug ?boolean if it requires <debug_type> debug to be enabled
---@param debug_type ?integer the type of message, 0 = debug (debug.chat) | 1 = error (debug.chat) | 2 = profiler (debug.profiler) 
---@param peer_id ?integer if you want to send it to a specific player, leave empty to send to all players
function ExecutionQueue.print(message, requires_debug, debug_type, peer_id)
	if not d then
		s.announce("alu", tostring(message))
		return
	end

	d.print(message, requires_debug, debug_type, peer_id)
end

function ExecutionQueue.tick()
	local queued_executions_to_remove = {}

	for i = 1, #queued_executions do
		local queued_execution = queued_executions[i]
		queued_execution:tick()

		if queued_execution.expired then
			--[[
				insert at start to ensure that it removes the ones with the greatest indecies first
				otherwise would cause issues where for example, it has to remove index 1 and 2, so it
				removes index 1, but now index 2 is index 1, so when it would go to remove index 2
				it would actually then remove index 3, leaving index 2 to still be there.
			]]
			table.insert(queued_executions_to_remove, 1, i)
		end
	end

	for i = 1, #queued_executions_to_remove do
		table.remove(queued_executions, queued_executions_to_remove[i])
	end
end

-- Queue a function to be called when the condition is true, store variables you may want to use in variable_table, and then index the stored variables in the functions via "self:getVar(variable_index)" and self must be defined as a parametre for the function. NOTE: on reloads, all queued_executions will be deleted, this is because we cannot store functions in g_savedata. If you need it after reloads as well, consider trying to rebuild the queued functions in onCreate().
---@param execute_condition function this function must return true for function_to_execute to be executed.
---@param function_to_execute function this function will be executed when execute_condition is true.
---@param variable_table table? use this table to store variables you'll want to use in execute_condition and/or function_to_execute, index these variables in the functions via "self:getVar(variable_index)", and self must be defined as a parametre for the function.
---@param execute_count integer? the number of times this can be executed, once it hits 0, it will be removed, set to -1 for infinite executions (until reload), defaults to 1
---@param expire_timer number? the number of ticks until it expires, once it hits 0, it will be removed, set to -1 to never expire (until reload), defaults to -1
---@return boolean is_success if it successfully the queued execution
function ExecutionQueue.queue(execute_condition, function_to_execute, variable_table, execute_count, expire_timer)

	if not execute_condition then
		eq.print("(ExecutionQueue) execute_condition is not defined!", true, 1)
		return false
	end

	if type(execute_condition) ~= "function" then
		eq.print(("(ExecutionQueue) execute_condition is not a function! (execute_condition: %s type: %s"):format(tostring(execute_condition), type(execute_condition)), true, 1)
		return false
	end

	if not function_to_execute then
		eq.print("(ExecutionQueue) function_to_execute is not defined!", true, 1)
		return false
	end

	if type(function_to_execute) ~= "function" then
		eq.print(("(ExecutionQueue) function_to_execute is not a function! (function_to_execute: %s type: %s"):format(tostring(function_to_execute), type(function_to_execute)), true, 1)
		return false
	end

	variable_table = variable_table or {}

	local queued_execution = {
		variable_table = variable_table,
		execute_condition = execute_condition,
		function_to_execute = function_to_execute,
		execute_count = execute_count or 1,
		expire_timer = expire_timer or -1,
		expired = false
	}

	function queued_execution:getVar(variable_index)
		return self.variable_table[variable_index]
	end

	function queued_execution:tick()
		-- see if we've met the execution conditions
		if self:execute_condition() then
			-- execute the function
			self:function_to_execute()

			-- decrement execute_count
			self.execute_count = self.execute_count - 1
		end

		-- decrement expire_timer
		self.expire_timer = self.expire_timer - 1

		-- if we're expired/fully used
		if self.execute_count == 0 or self.expire_timer == 0 then
			-- expire self, to be deleted.
			self.expired = true
		end
	end

	table.insert(queued_executions, queued_execution)

	return true
end