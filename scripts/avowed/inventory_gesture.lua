--[[
Inventory gesture for Avowed: left grip with the left hand at the left shoulder opens the inventory.

The gamepad inventory is a TAP of View/Back (Context_GP_Menus: Gamepad_Special_Left + InputTriggerTap 0.4 s ->
Action_OpenLedger; a 0.6 s hold is Action_TrackNewQuest). UEVR only sends Back on a LONG press of the left system
button, for a single XInput poll (VR.cpp handle_select_button), which does not always register, and Back injected
from Lua did not open it either. The keyboard I key opens the inventory reliably, so the gesture sends I through
plugins/luakey.dll (the fixed build from the Stalker 2 profile: a custom event named after the key, "down" / "up").

The shoulder zone is a sphere placed relative to the headset, turned with the head's yaw only (pitch / roll ignored),
so it stays on the shoulder while looking around. The grip press that fires the gesture is consumed: the game does
not see it as LB. Lives in scripts/avowed/ (see physical_melee.lua for why) and is required by main.lua.
]]--

local uevrUtils = require('libs/uevr_utils')
local controllers = require('libs/controllers')
local configui = require('libs/configui')

local vr = uevr.params.vr

local M = {}

local INPUT_PRIORITY = 10 -- ahead of main.lua's input callback (5), which reads LB for the aim hand

local settings = {
	enabled = true,
	radius = 18,
	offset = { fwd = -5, right = -17, up = -22 }, -- cm from the headset: behind, left, below
	holdSeconds = 0.1,
	debug = false,
}

local configWidgets = {
	{ widgetType = "checkbox", id = "ig_enabled", label = "Inventory Gesture (left grip at left shoulder)", initialValue = true },
	{ widgetType = "slider_float", id = "ig_radius", label = "Shoulder Zone Size (cm)", speed = 0.5, range = {8, 40}, initialValue = 18 },
	{ widgetType = "drag_float3", id = "ig_offset", label = "Shoulder Zone From Head (fwd, right, up cm)", speed = 0.5, range = {-60, 60}, initialValue = {-5, -17, -22} },
	{ widgetType = "slider_float", id = "ig_hold", label = "Inventory Key Hold (s)", speed = 0.01, range = {0.05, 1.0}, initialValue = 0.1 },
	{ widgetType = "checkbox", id = "ig_debug", label = "Inventory Gesture Debug Log", initialValue = false },
}

function M.getConfigurationWidgets()
	return configWidgets
end

configui.onCreateOrUpdate("ig_enabled", function(value) settings.enabled = value ~= false end)
configui.onCreateOrUpdate("ig_radius", function(value) settings.radius = value end)
configui.onCreateOrUpdate("ig_hold", function(value) settings.holdSeconds = value end)
configui.onCreateOrUpdate("ig_debug", function(value) settings.debug = value == true end)
configui.onCreateOrUpdate("ig_offset", function(value)
	-- a Vector3f from the widget, or a table / array from the saved file
	if value == nil then return end
	local x = value.x or value.X or value[1]
	local y = value.y or value.Y or value[2]
	local z = value.z or value.Z or value[3]
	if x ~= nil and y ~= nil and z ~= nil then
		settings.offset = { fwd = x, right = y, up = z }
	end
end)

local function log(text)
	if settings.debug then
		uevr.params.functions.log_info("[inventory_gesture] " .. text) --log.txt; print() does not reach it
	end
end

-- the left hand's position relative to the headset, in the head's yaw frame (cm): forward, right, up
local function handOffsetFromHead()
	local hand = controllers.getControllerLocation(Handed.Left)
	local head = controllers.getControllerLocation(2)
	local headRot = controllers.getControllerRotation(2)
	if hand == nil or head == nil or headRot == nil then return nil end
	local dx, dy, dz = hand.X - head.X, hand.Y - head.Y, hand.Z - head.Z
	local yaw = math.rad(headRot.Yaw)
	local c, s = math.cos(yaw), math.sin(yaw)
	return dx * c + dy * s, -dx * s + dy * c, dz
end

local function isAtShoulder()
	local fwd, right, up = handOffsetFromHead()
	if fwd == nil then return false end
	local o = settings.offset
	local df, dr, du = fwd - o.fwd, right - o.right, up - o.up
	local inside = df * df + dr * dr + du * du <= settings.radius * settings.radius
	log(string.format("left grip: hand fwd %.0f right %.0f up %.0f -> %s", fwd, right, up, inside and "AT SHOULDER" or "no"))
	return inside
end

local function haptic()
	pcall(function()
		vr.trigger_haptic_vibration(0, 0.1, 1.0, 0.8, vr.get_left_joystick_source())
	end)
end

-- luakey.dll protocol: event name = the key (one character), data = "down" / "up"
local INVENTORY_KEY = "I"
local function pressInventoryKey()
	uevr.api:dispatch_custom_event(INVENTORY_KEY, "down")
	delay(math.floor(settings.holdSeconds * 1000), function()
		uevr.api:dispatch_custom_event(INVENTORY_KEY, "up")
	end)
	log("sent " .. INVENTORY_KEY .. " key")
end

local wasGripDown = false
local consumingGrip = false -- the grip press that fired the gesture is hidden from the game until it is released

uevrUtils.registerOnPreInputGetStateCallback(function(retval, user_index, state)
	local gripDown = uevrUtils.isButtonPressed(state, XINPUT_GAMEPAD_LEFT_SHOULDER)
	if consumingGrip then
		if not gripDown then consumingGrip = false end
	elseif settings.enabled and gripDown and not wasGripDown and uevrUtils.getValid(pawn) ~= nil and isAtShoulder() then
		consumingGrip = true
		pressInventoryKey()
		haptic()
	end
	wasGripDown = gripDown
	if consumingGrip then uevrUtils.unpressButton(state, XINPUT_GAMEPAD_LEFT_SHOULDER) end
end, INPUT_PRIORITY)

return M
