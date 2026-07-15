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

	Containts the includes for the default command modules.

]]

-- Adds the generic commands, eg: "info"
require("libraries.addon.commands.command.definitions.genericCommands")

-- Adds the variable interaction commands, eg: "print_variable", "set_variable"
require("libraries.addon.commands.command.definitions.variableInteractionCommands")