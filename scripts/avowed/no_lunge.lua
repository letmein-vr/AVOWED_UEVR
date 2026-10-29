--[[
Stops weapon attacks dashing the player toward their target.

Avowed's weapon attack abilities (GameplayAbility_PlayerWeaponAction, one per combo step, e.g.
PWA_Melee_Primary_1HSword_Combo_01..04) carry an optional dash for each release type:
HoldReleasePlayerMoveToActorForceParameters / QuickReleasePlayerMoveToActorForceParameters. It names a
PlayerMoveToActorForce_* parameters class, e.g. PlayerMoveToActorForce_1HSword_Power_C on every 1H sword strong
attack: up to 7 m toward the target ending 50 cm from it (MaxTrackingDistance 700, FinalDistanceBetweenCapsules 50),
turning the player to face it, or 4 m straight on with no target. In VR that is an unasked-for slide. Quick
attacks of the 1H sword have no dash (the slot is empty), so emptying the slot gives strong attacks the same handling.

Lives in scripts/avowed/ and is required by main.lua (UEVR runs every .lua in the scripts root by itself).
]]--

local uevrUtils = require('libs/uevr_utils')
local configui = require('libs/configui')

local M = {}

local ABILITY_CLASS = "Class /Script/Alabama.GameplayAbility_PlayerWeaponAction"
local DASH_FIELDS = { "HoldReleasePlayerMoveToActorForceParameters", "QuickReleasePlayerMoveToActorForceParameters" }
local POLL_MS = 1000

local enabled = true
local cleared = {} -- { ability, field, original, isDefault }: what was emptied, for restoring when switched off

-- one setting per melee mode (main.lua shows the active mode's and calls M.setEnabled)
local configWidgets = {
	{ widgetType = "checkbox", id = "melee_no_lunge", label = "Stop Attack Lunges (dash toward target)", initialValue = true },
	{ widgetType = "checkbox", id = "melee_swing_no_lunge", label = "Stop Attack Lunges (dash toward target)##swing", initialValue = false },
}

function M.getConfigurationWidgets()
	return configWidgets
end

-- class defaults are included so abilities granted later (weapon change, level load) start without the dash
local function clearDashes()
	for _, ability in ipairs(uevrUtils.find_all_instances(ABILITY_CLASS, true) or {}) do
		for _, field in ipairs(DASH_FIELDS) do
			pcall(function()
				local value = ability[field]
				if value ~= nil then
					local isDefault = string.find(ability:get_full_name(), "Default__", 1, true) ~= nil
					cleared[#cleared + 1] = { ability = ability, field = field, original = value, isDefault = isDefault }
					ability[field] = nil
				end
			end)
		end
	end
end

local function restoreDashes()
	for _, entry in ipairs(cleared) do
		pcall(function()
			if uevrUtils.getValid(entry.ability) ~= nil then entry.ability[entry.field] = entry.original end
		end)
	end
	cleared = {}
end

function M.setEnabled(value)
	enabled = value ~= false
	if not enabled then restoreDashes() end
end

setInterval(POLL_MS, function()
	if enabled then clearDashes() end
end)

uevrUtils.registerPreLevelChangeCallback(function(level)
	--live abilities of the old world are gone and their addresses get reused; class defaults stay
	local kept = {}
	for _, entry in ipairs(cleared) do
		if entry.isDefault then kept[#kept + 1] = entry end
	end
	cleared = kept
end)

uevr.params.sdk.callbacks.on_script_reset(function()
	restoreDashes()
end)

return M
