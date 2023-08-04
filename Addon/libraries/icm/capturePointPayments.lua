--[[
	
Copyright 2023 Liam Matthews

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

require("libraries.addon.script.debugging")

CapturePointPayments = {}

local payroll_oversleeping_messages = {
	"I'm not paying for your sleeping expenses!",
	"Never heard of using sleeping as a defence before. Neither will your payroll.",
	"The beds are there to fill either patients or the enemies with, not yourself.",
	"Why save lives when you can sleep more than 12 hours a day? To get your payroll, of course."
}

local payroll_payout_messages = {
	"Great job holding the points, I've sent your payroll of $@{payout}.",
	"Good work, your payroll of $@{payout} has been sent.",
	"Keep up the good work, I've sent you $@{payout} for your efforts."
}

---@param game_ticks number the game_ticks given by onTick()
function CapturePointPayments.tick(game_ticks)
	if not g_savedata.settings.CAPTURE_POINT_PAYMENTS then
		return
	end

	CapturePointPayments.incrementSleepTracker(game_ticks)

	local current_date = CapturePointPayments.getDate()

	-- check if its time to do the payroll
	if current_date - g_savedata.libraries.capture_point_payments.last_payout >= g_savedata.flags.capture_point_payroll_frequency then
		
		if CapturePointPayments.getSleepRatio() < g_savedata.flags.capture_point_payroll_sleep_ratio_max then
			server.notify(-1, "Capture Point Payroll", payroll_oversleeping_messages[math.random(1, #payroll_oversleeping_messages)], 7)

			-- reset the sleep tracker for the new week
			CapturePointPayments.resetSleepTracker()

			return
		end

		local payroll_per_island = g_savedata.flags.capture_point_pay_amount

		-- the player always holds their main base, so give them that amount.
		local pay_amount = payroll_per_island * g_savedata.player_base_island.payroll_multiplier

		for _, capture_point in pairs(g_savedata.islands) do
			if capture_point.faction == ISLAND.FACTION.PLAYER then
				pay_amount = pay_amount + payroll_per_island * capture_point.payroll_multiplier
			end
		end

		local player_currency = server.getCurrency()
		local player_research = server.getResearchPoints()

		server.setCurrency(player_currency + pay_amount, player_research)

		local payout_message = payroll_payout_messages[math.random(1, #payroll_payout_messages)]

		payout_message = payout_message:gsub("@{payout}", pay_amount)

		server.notify(-1, "Capture Point Payroll", payout_message, 4)

		-- reset the sleep tracker for the new week
		CapturePointPayments.resetSleepTracker()
	end
end

-- increments the sleep tracker.
---@param game_ticks number the game_ticks given by onTick(), 1 means the player is not sleeping, 400 means the player is sleeping.
function CapturePointPayments.incrementSleepTracker(game_ticks)
	-- increment the number of this tick (game_ticks 400 is sleeping, game_ticks 1 is normal)

	local sleep_tracker = g_savedata.libraries.capture_point_payments.sleep_tracker

	if game_ticks == 1 then
		sleep_tracker.normal = sleep_tracker.normal + 1
	end

	sleep_tracker.total = sleep_tracker.total + game_ticks
end

-- gets the current date, along with the % of the current day
---@return number current_date the current day plus the current day percentage.
function CapturePointPayments.getDate()
	local time_data = server.getTime()

	local total_days = server.getDateValue()

	return total_days + time_data.percent
end

-- resets the sleep tracker
function CapturePointPayments.resetSleepTracker()
	g_savedata.libraries.capture_point_payments.sleep_tracker = {
		normal = 0,
		total = 0
	}

	g_savedata.libraries.capture_point_payments.last_payout = server.getDateValue() + g_savedata.flags.capture_point_pay_time
end

-- Gets the sleep ratio
---@return number sleep_ratio value of 0-1, if the player has consantly been sleeping, the value will be 0, if the player has never slept, then the value will be 1.
function CapturePointPayments.getSleepRatio()
	local sleep_tracker = g_savedata.libraries.capture_point_payments.sleep_tracker

	return sleep_tracker.normal/sleep_tracker.total
end

--[[


Flag Registers


]]

--[[
Number Flags
]]

--[[
	capture_point_payroll_frequency flag,
	controls the frequency of which you get a payroll for how many capture points you hold in days.
]]
Flag.registerNumberFlag(
	"capture_point_payroll_frequency",
	7,
	{
		"balance",
		"capture points",
		"payroll",
		"no performance impact"
	},
	"normal",
	"admin",
	nil,
	"Controls the frequency of which you get a payroll for how many capture points you hold in days.",
	nil,
	nil
)

--[[
	capture_point_payroll_frequency flag,
	controls how much money you get per capture point you hold.
]]
Flag.registerNumberFlag(
	"capture_point_pay_amount",
	700,
	{
		"balance",
		"capture points",
		"payroll",
		"no performance impact"
	},
	"normal",
	"admin",
	nil,
	"Controls how much money you get per capture point you hold.",
	0,
	nil
)

--[[ 
	capture_point_payroll_frequency flag,
	controls at which time of the day you will recieve the payment, 
	may have strange behaviour when the payroll frequency is less than 1.
]]
Flag.registerNumberFlag(
	"capture_point_pay_time",
	0.2916666667,
	{
		"balance",
		"capture points",
		"payroll",
		"no performance impact"
	},
	"normal",
	"admin",
	nil,
	"Controls at which time of the day you will recieve the payment, may have strange behaviour when the payroll frequency is less than 1.",
	0,
	1
)

--[[
	capture_point_payroll_sleep_ratio_max flag,
	controls the minimum amount of time you must've spent not asleep for you to get the payroll.
]]
Flag.registerNumberFlag(
	"capture_point_payroll_sleep_ratio_max",
	0.3,
	{
		"balance",
		"capture points",
		"payroll",
		"no performance impact"
	},
	"normal",
	"admin",
	nil,
	"Controls the minimum amount of time you must've spent not asleep for you to get the payroll.",
	0,
	1
)