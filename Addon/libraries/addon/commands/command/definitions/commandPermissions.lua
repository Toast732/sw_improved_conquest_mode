--[[
	
Copyright 2024 Liam Matthews

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

--[[

	Registers the default command permissions.

]]

-- None Permission
Command.registerPermission(
	"none",
	function()
		return true
	end
)

-- Auth Permission
Command.registerPermission(
	"auth",
	function(peer_id)

		-- this is a script, skip check.
		if peer_id == -1 then return false end

		local players = server.getPlayers()

		for peer_index = 1, #players do
			local player = players[peer_index]

			if player.id == peer_id then
				return player.auth
			end
		end

		return false
	end
)

-- Admin Permission
Command.registerPermission(
	"admin",
	function(peer_id)

		-- this is a script, skip check.
		if peer_id == -1 then return false end

		local players = server.getPlayers()

		for peer_index = 1, #players do
			local player = players[peer_index]

			if player.id == peer_id then
				return player.admin
			end
		end

		return false
	end
)

-- Script Permission
Command.registerPermission(
	"script",
	function(peer_id)
		return peer_id == -1
	end
)

-- Auth Script Permission
Command.registerPermission(
	"auth_script",
	function(peer_id)

		-- this is a script, skip check.
		if peer_id == -1 then return true end

		local players = server.getPlayers()

		for peer_index = 1, #players do
			local player = players[peer_index]

			if player.id == peer_id then
				return player.auth
			end
		end

		return false
	end
)

-- Admin Script Permission
Command.registerPermission(
	"admin_script",
	function(peer_id)

		-- this is a script, skip check.
		if peer_id == -1 then return true end

		local players = server.getPlayers()

		for peer_index = 1, #players do
			local player = players[peer_index]

			if player.id == peer_id then
				return player.admin
			end
		end

		return false
	end
)