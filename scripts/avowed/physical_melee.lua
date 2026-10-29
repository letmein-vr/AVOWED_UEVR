--[[
Physical (contact) melee for Avowed: the right-hand weapon has to touch an enemy or a breakable to attack.
Lives in scripts/avowed/ and is required by main.lua: UEVR runs every .lua in the scripts root by itself, which would
run a module there twice.

How Avowed's melee hits work (live MCP, 2026-10-28): the player's attack montages (AM_1HSword_Combo_*_QuickRelease /
_HoldRelease) use AnimNotifyState_ActivateCustomHitDetection with AttachedCollisionShapes on "FPVCameraSocket" and
BakedSocketData pivoting on the same socket (BakedVersionNumber 1). The hit is a pre-recorded shape swept from the
first person camera socket - where the VR weapon actually is plays no part. That socket follows the pawn, whose yaw
is the control rotation (pitch stays 0), which input.lua drives from the right controller (aimMethod RIGHT_CONTROLLER).

So this module:
	1. tests points along the gripped weapon (its mesh bounds, longest axis) against nearby hostile characters'
	   capsules and intact breakables' bounds boxes, every tick;
	2. on a touch while the hand moves fast enough, calls the strike callback set by main.lua (normal tap or strong
	   hold, chosen by hand speed exactly like the swipe gesture);
	3. steers the swept shape at the touched point for the hit window, through input's aim rotation offset, so a
	   blade that touches something beside the controller's aim still hits it.
Hellraiser needed a native plugin for step 3 (its fan is camera-centred); here the aim rotation is enough.
]]--

local uevrUtils = require('libs/uevr_utils')
local controllers = require('libs/controllers')
local configui = require('libs/configui')
local attachments = require('libs/attachments')
local input = require('libs/input')

local vr = uevr.params.vr

local M = {}

local ENEMY_CLASS = "Class /Script/Alabama.AlabamaBaseCharacter"
local BREAKABLE_CLASS = "Class /Script/Alabama.AlabamaDestructible"
local ENEMY_SCAN_SECONDS = 0.5
local BREAKABLE_SCAN_SECONDS = 2.0
local CONTACT_POINT_COUNT = 6
local CONTACT_POINT_START = 0.15 -- share of the grip-to-far-end distance where the first contact point sits
local CONTACT_POINT_RADIUS = 4.0 -- cm, roughly blade thickness
local FIST_RADIUS = 8.0
local CONTACT_REARM_SECONDS = 0.15 -- leaving and re-entering faster than this does not count as a new touch
local STRIKE_COOLDOWN = 0.35
local STRENGTH_MIN_SPEED = 180 -- same floor as the swipe detector, so strength means the same in both modes
local STEER_AFTER_RELEASE = 0.15 -- seconds the steer is held after a strong attack's release (its hit window)

local settings = {
	enabled = true,
	forgiveness = 0.3,
	refire = 0.5,
	steer = true,
	steerTime = 0.3,
	strikeDelay = 2,
	breakables = true,
	range = 400,
	debug = false,
}

-- on / off comes from main.lua's Melee Mode (M.setEnabled)
local configWidgets = {
	{ widgetType = "slider_float", id = "pm_forgiveness", label = "Hit Forgiveness (0 strict - 1 easy)", speed = 0.01, range = {0.0, 1.0}, initialValue = 0.3 },
	{ widgetType = "slider_float", id = "pm_refire", label = "Re-hit While Touching After (s)", speed = 0.01, range = {0.2, 1.5}, initialValue = 0.5 },
	{ widgetType = "checkbox", id = "pm_steer", label = "Aim Hit At Touched Point", initialValue = true },
	{ widgetType = "slider_float", id = "pm_steer_time", label = "Aim Hold Time (s)", speed = 0.01, range = {0.1, 1.0}, initialValue = 0.3 },
	{ widgetType = "slider_int", id = "pm_strike_delay", label = "Strike Delay (ticks after aiming)", range = {0, 6}, initialValue = 2 },
	{ widgetType = "checkbox", id = "pm_breakables", label = "Hit Breakables", initialValue = true },
	{ widgetType = "slider_float", id = "pm_range", label = "Target Scan Range (cm)", speed = 10.0, range = {200, 1000}, initialValue = 400 },
	{ widgetType = "checkbox", id = "pm_debug", label = "Physical Melee Debug Log", initialValue = false },
}
local settingIDs = { pm_forgiveness = "forgiveness", pm_refire = "refire", pm_steer = "steer",
	pm_steer_time = "steerTime", pm_strike_delay = "strikeDelay", pm_breakables = "breakables", pm_range = "range", pm_debug = "debug" }
for id, key in pairs(settingIDs) do
	configui.onCreateOrUpdate(id, function(value) settings[key] = value end)
end

-- Hit Forgiveness (0-1) scales everything that decides whether a touch counts:
--	contact buffer: how far outside a target's capsule / box a weapon point may be (2 -> 30 cm)
--	min hand speed: how fast the hand must move for the touch to attack (150 -> 30 cm/s)
--	look-ahead: points are also tested where the swing will put them shortly, so a fast swing cannot pass
--	through a target between two ticks (0 -> 0.08 s)
local function hitBuffer() return 2 + 28 * settings.forgiveness end
local function contactSpeed() return 150 - 120 * settings.forgiveness end
local function lookAhead() return 0.08 * settings.forgiveness end

function M.getConfigurationWidgets()
	return configWidgets
end

local function log(text)
	if settings.debug then
		uevr.params.functions.log_info("[physical_melee] " .. text) --log.txt; print() does not reach it
	end
end

local strikeCallback = nil
-- callback(strength, hand, steering) - main.lua decides tap vs strong hold, as for a swipe
function M.setStrikeCallback(callback)
	strikeCallback = callback
end

function M.isActive()
	return settings.enabled == true
end

function M.setEnabled(value)
	settings.enabled = value == true
end

-- ---------------------------------------------------------------------------------------------
-- Targets
-- ---------------------------------------------------------------------------------------------
local enemies = {}     -- { actor, X, Y, Z, r, hh }
local breakables = {}  -- { actor, X, Y, Z, ex, ey, ez } (bounds centre / extent)
local breakableList = {}
local nextEnemyScan, nextBreakableScan = 0, 0

local function distance2(a, b)
	local dx, dy, dz = a.X - b.X, a.Y - b.Y, a.Z - b.Z
	return dx * dx + dy * dy + dz * dz
end

local function scanEnemies(ploc)
	local out = {}
	local range2 = settings.range * settings.range
	for _, actor in ipairs(uevrUtils.find_all_instances(ENEMY_CLASS, false) or {}) do
		if actor ~= pawn then
			pcall(function()
				local loc = actor:K2_GetActorLocation()
				if loc == nil or distance2(loc, ploc) > range2 then return end
				if actor:IsAlive() ~= true or actor:IsHostileTowards(pawn) ~= true then return end
				local r, hh = 40.0, 90.0
				local capsule = actor.CapsuleComponent
				if capsule ~= nil then
					r = capsule:GetScaledCapsuleRadius() or r
					hh = capsule:GetScaledCapsuleHalfHeight() or hh
				end
				out[#out + 1] = { actor = actor, X = loc.X, Y = loc.Y, Z = loc.Z, r = r, hh = hh }
			end)
		end
	end
	enemies = out
end

-- the level's breakables only change when something breaks, so their bounds are re-read every few seconds
local function rebuildBreakables()
	local list = {}
	for _, actor in ipairs(uevrUtils.find_all_instances(BREAKABLE_CLASS, false) or {}) do
		pcall(function()
			local origin, extent = uevrUtils.vector(0, 0, 0), uevrUtils.vector(0, 0, 0)
			actor:GetActorBounds(true, origin, extent, false)
			if extent.X <= 0 and extent.Y <= 0 and extent.Z <= 0 then return end
			list[#list + 1] = { actor = actor, X = origin.X, Y = origin.Y, Z = origin.Z, ex = extent.X, ey = extent.Y, ez = extent.Z }
		end)
	end
	breakableList = list
end

local function filterBreakables(ploc)
	local out = {}
	local range2 = settings.range * settings.range
	for _, b in ipairs(breakableList) do
		if distance2(b, ploc) <= range2 then
			pcall(function()
				if uevrUtils.getValid(b.actor) ~= nil and (b.actor.CurrentHealth or 0) > 0 then out[#out + 1] = b end
			end)
		end
	end
	breakables = out
end

local function refreshTargets(now)
	local ploc = uevrUtils.getValid(pawn) ~= nil and pawn:K2_GetActorLocation() or nil
	if ploc == nil then enemies, breakables = {}, {} return end
	if now >= nextEnemyScan then
		nextEnemyScan = now + ENEMY_SCAN_SECONDS
		scanEnemies(ploc)
		if settings.breakables then
			if now >= nextBreakableScan then
				nextBreakableScan = now + BREAKABLE_SCAN_SECONDS
				rebuildBreakables()
			end
			filterBreakables(ploc)
		else
			breakables = {}
		end
	else
		for _, e in ipairs(enemies) do --enemies move; their positions are read every tick between scans
			pcall(function()
				local loc = e.actor:K2_GetActorLocation()
				if loc ~= nil then e.X, e.Y, e.Z = loc.X, loc.Y, loc.Z end
			end)
		end
	end
end

-- ---------------------------------------------------------------------------------------------
-- Contact points along the gripped weapon
-- ---------------------------------------------------------------------------------------------
local meshAxisCache = {} -- StaticMesh full name -> { axis = "X"/"Y"/"Z", far, cx, cy, cz }

local function getMeshAxis(mesh)
	local key = mesh:get_full_name()
	local cached = meshAxisCache[key]
	if cached ~= nil then return cached end
	local box = mesh:GetBoundingBox()
	if box == nil or box.Min == nil or box.Max == nil then return nil end
	local size = { X = box.Max.X - box.Min.X, Y = box.Max.Y - box.Min.Y, Z = box.Max.Z - box.Min.Z }
	local axis = "X"
	if size.Y > size[axis] then axis = "Y" end
	if size.Z > size[axis] then axis = "Z" end
	-- the grip is at the mesh origin; the striking end is whichever end of the longest axis lies farther from it
	local far = math.abs(box.Max[axis]) >= math.abs(box.Min[axis]) and box.Max[axis] or box.Min[axis]
	cached = { axis = axis, far = far, cx = (box.Max.X + box.Min.X) / 2, cy = (box.Max.Y + box.Min.Y) / 2, cz = (box.Max.Z + box.Min.Z) / 2 }
	meshAxisCache[key] = cached
	return cached
end

local function contactPoints()
	local weapon = uevrUtils.getValid(attachments.getCurrentGrippedAttachment(Handed.Right))
	local mesh = weapon ~= nil and uevrUtils.getValid(weapon.StaticMesh) or nil
	if mesh == nil then
		local hand = controllers.getControllerLocation(Handed.Right) --unarmed: the fist
		if hand == nil then return nil end
		return { { X = hand.X, Y = hand.Y, Z = hand.Z, r = FIST_RADIUS } }
	end
	local info = getMeshAxis(mesh)
	if info == nil then return nil end
	local loc = weapon:K2_GetComponentLocation()
	local scale = weapon:K2_GetComponentScale()
	local axes = { X = weapon:GetForwardVector(), Y = weapon:GetRightVector(), Z = weapon:GetUpVector() }
	local pts = {}
	for i = 0, CONTACT_POINT_COUNT - 1 do
		local t = CONTACT_POINT_START + (1 - CONTACT_POINT_START) * i / (CONTACT_POINT_COUNT - 1)
		local localPt = { X = info.cx, Y = info.cy, Z = info.cz }
		localPt[info.axis] = info.far * t
		local x, y, z = localPt.X * scale.X, localPt.Y * scale.Y, localPt.Z * scale.Z
		pts[#pts + 1] = {
			X = loc.X + axes.X.X * x + axes.Y.X * y + axes.Z.X * z,
			Y = loc.Y + axes.X.Y * x + axes.Y.Y * y + axes.Z.Y * z,
			Z = loc.Z + axes.X.Z * x + axes.Y.Z * y + axes.Z.Z * z,
			r = CONTACT_POINT_RADIUS,
		}
	end
	return pts
end

-- returns the touched point on the target (kept inside its capsule / box) or nil
local function touchPoint(pt, target, isBreakable)
	local pad = pt.r + hitBuffer()
	if isBreakable then
		if math.abs(pt.X - target.X) <= target.ex + pad and math.abs(pt.Y - target.Y) <= target.ey + pad and math.abs(pt.Z - target.Z) <= target.ez + pad then
			return { X = target.X, Y = target.Y, Z = target.Z }
		end
		return nil
	end
	local dx, dy, dz = pt.X - target.X, pt.Y - target.Y, pt.Z - target.Z
	local r = target.r + pad
	local h2 = dx * dx + dy * dy
	if h2 > r * r or math.abs(dz) > target.hh + pad then return nil end
	local h = math.sqrt(h2)
	local k = h > target.r and target.r / h or 1.0
	return { X = target.X + dx * k, Y = target.Y + dy * k, Z = target.Z + math.max(-target.hh, math.min(target.hh, dz)) }
end

local function findTouchAt(pt)
	for _, e in ipairs(enemies) do
		local p = touchPoint(pt, e, false)
		if p ~= nil then return p, e.actor end
	end
	for _, b in ipairs(breakables) do
		local p = touchPoint(pt, b, true)
		if p ~= nil then return p, b.actor end
	end
	return nil, nil
end

-- velocity: the hand's (relative to the head); each point is also probed where it will be lookAhead() seconds on
local function findTouch(pts, velocity)
	local lead = lookAhead()
	for _, pt in ipairs(pts) do
		local p, actor = findTouchAt(pt)
		if p ~= nil then return p, actor end
		if lead > 0 and velocity ~= nil then
			p, actor = findTouchAt({ X = pt.X + velocity.X * lead, Y = pt.Y + velocity.Y * lead, Z = pt.Z + velocity.Z * lead, r = pt.r })
			if p ~= nil then return p, actor end
		end
	end
	return nil, nil
end

-- ---------------------------------------------------------------------------------------------
-- Steering the swept hit shape at the touched point
-- ---------------------------------------------------------------------------------------------
-- In Avowed input.lua runs with playerControllerRotationFollowsBody (default): ControlRotation = (0, body yaw, 0)
-- every tick and the aim rotation offset only moves the aim camera. The sweep therefore always faced the body, level,
-- at head height - low targets such as crates on the floor were under it. For the strike window input is switched to
-- the controller path (ControlRotation = controller rotation composed with the aim offset), and the offset turns the
-- result to face the touched point from the head, pitch included. Restored when the window ends.
local steer = { untilTime = 0, target = nil, active = false }

local function quatFromRotator(r)
	return kismet_math_library:Quat_MakeFromEuler(uevrUtils.vector(r.Roll, r.Pitch, r.Yaw))
end

local function endSteer()
	steer.active = false
	input.setAimRotationOffset({Pitch = 0, Yaw = 0, Roll = 0})
	input.setPlayerControllerRotationFollowsBody(true)
end

-- input.lua applies the offset as ComposeRotators(offset, controllerRotation), i.e. in the controller's frame, so the
-- offset that turns the result to face the target is controller^-1 * desired
local function updateSteer(now)
	if not steer.active then return end
	if now >= steer.untilTime or uevrUtils.getValid(pawn) == nil then
		endSteer()
		return
	end
	local ctrlRot = controllers.getControllerRotation(Handed.Right)
	local head = controllers.getControllerLocation(2)
	if ctrlRot == nil or head == nil then return end
	local dx, dy, dz = steer.target.X - head.X, steer.target.Y - head.Y, steer.target.Z - head.Z
	local desiredYaw = math.deg(math.atan(dy, dx))
	local desiredPitch = math.deg(math.atan(dz, math.sqrt(dx * dx + dy * dy)))
	local desired = uevrUtils.rotator(desiredPitch, desiredYaw, 0)
	local offset = kismet_math_library:Quat_Rotator(kismet_math_library:Multiply_QuatQuat(kismet_math_library:Quat_Inversed(quatFromRotator(ctrlRot)), quatFromRotator(desired)))
	input.setAimRotationOffset(offset)
	if settings.debug then
		-- whether the hit sweep's pivot socket actually turns with the control rotation (pitch especially)
		pcall(function()
			local control = pawn.Controller.ControlRotation
			local socket = pawn.FirstPersonSkelMesh:GetSocketRotation(uevrUtils.fname_from_string("FPVCameraSocket"))
			log(string.format("steer want p%.0f y%.0f | control p%.0f y%.0f | socket p%.0f y%.0f",
				desiredPitch, desiredYaw, control.Pitch, control.Yaw, socket.Pitch, socket.Yaw))
		end)
	end
end

local function startSteer(target, seconds)
	steer.target = target
	steer.untilTime = os.clock() + seconds
	steer.active = true
	input.setPlayerControllerRotationFollowsBody(false)
	updateSteer(os.clock()) --in place before the attack starts: its hit window comes 1-3 ticks later
end

-- ---------------------------------------------------------------------------------------------
-- Per tick
-- ---------------------------------------------------------------------------------------------
local prevHand, prevHead, prevTime = nil, nil, nil
local inContact, contactLostAt, lastFire, cooldownUntil = false, nil, 0, 0

local function resetMotion()
	prevHand, prevHead, prevTime = nil, nil, nil
	inContact, contactLostAt = false, nil
end

-- returns speed (cm/s) and velocity of the hand relative to the head, so walking or turning does not count as a swing
local function handMotion(now)
	local hand = controllers.getControllerLocation(Handed.Right)
	local head = controllers.getControllerLocation(2)
	if hand == nil or head == nil then prevTime = nil return nil, nil end
	local speed, velocity = nil, nil
	if prevTime ~= nil then
		local dt = now - prevTime
		if dt > 0.0005 and dt < 0.1 then
			local dx = (hand.X - prevHand.X) - (head.X - prevHead.X)
			local dy = (hand.Y - prevHand.Y) - (head.Y - prevHead.Y)
			local dz = (hand.Z - prevHand.Z) - (head.Z - prevHead.Z)
			speed = math.sqrt(dx * dx + dy * dy + dz * dz) / dt
			velocity = { X = dx / dt, Y = dy / dt, Z = dz / dt }
		end
	end
	prevHand, prevHead, prevTime = { X = hand.X, Y = hand.Y, Z = hand.Z }, { X = head.X, Y = head.Y, Z = head.Z }, now
	return speed, velocity
end

local function strengthFromSpeed(speed)
	local ceiling = configui.getValue("melee_strong_swing_speed_ceiling") or 700
	if ceiling <= STRENGTH_MIN_SPEED then return 1 end
	return math.max(0, math.min(1, (speed - STRENGTH_MIN_SPEED) / (ceiling - STRENGTH_MIN_SPEED)))
end

local function haptic()
	pcall(function()
		vr.trigger_haptic_vibration(0, 0.12, 0.8, 1.0, vr.get_right_joystick_source())
	end)
end

-- Strike delay: the hit sweep's socket reaches the steered aim ~2 ticks after the steer starts (the control rotation
-- is set from the previous tick's controller pose, and the socket follows it a tick later), while the attack's first
-- hit checks come 1-3 ticks after it starts. So the steer starts on the touch and the attack itself waits
-- strikeDelay ticks; the aim hold window is counted from the attack, not the touch.
local pendingStrike = nil -- { ticks, strength, steerSeconds }

local function fireStrike(now, strength, steerSeconds)
	if steer.active and steerSeconds ~= nil then steer.untilTime = now + steerSeconds end
	if strikeCallback ~= nil then strikeCallback(strength, Handed.Right, settings.steer) end
end

local function updatePendingStrike(now)
	if pendingStrike == nil then return end
	pendingStrike.ticks = pendingStrike.ticks - 1
	if pendingStrike.ticks > 0 then return end
	local p = pendingStrike
	pendingStrike = nil
	fireStrike(now, p.strength, p.steerSeconds)
	log(string.format("strike fired after delay, strength %.2f", p.strength))
end

local function strike(now, speed, point, actor)
	lastFire = now
	cooldownUntil = now + STRIKE_COOLDOWN
	local strength = strengthFromSpeed(speed)
	local seconds = nil
	if settings.steer then
		seconds = settings.steerTime
		local strongThreshold = configui.getValue("melee_strong_swing_threshold") or 0.75
		if configui.getValue("melee_strong_swing_enabled") ~= false and strength >= strongThreshold then
			--a strong attack's hit comes on release, after the hold
			seconds = math.max(seconds, (configui.getValue("melee_strong_swing_hold_seconds") or 0.4) + STEER_AFTER_RELEASE)
		end
		startSteer(point, seconds)
	end
	local delayTicks = settings.steer and math.floor(settings.strikeDelay or 0) or 0
	if delayTicks > 0 then
		pendingStrike = { ticks = delayTicks, strength = strength, steerSeconds = seconds }
		steer.untilTime = math.huge --held until the delayed attack starts its own window
	else
		fireStrike(now, strength, seconds)
	end
	haptic()
	log(string.format("strike %s speed %.0f strength %.2f delay %d at (%.0f,%.0f,%.0f)", actor ~= nil and actor:get_fname():to_string() or "?", speed, strength, delayTicks, point.X, point.Y, point.Z))
end

local function tick(now)
	updateSteer(now)
	updatePendingStrike(now)
	if not settings.enabled or not attachments.isActiveAttachmentMelee(Handed.Right) or uevrUtils.getValid(pawn) == nil then
		resetMotion()
		return
	end
	refreshTargets(now)
	local speed, velocity = handMotion(now)
	if speed == nil then return end
	if #enemies == 0 and #breakables == 0 then
		inContact = false
		return
	end
	local pts = contactPoints()
	if pts == nil then return end
	local point, actor = findTouch(pts, velocity)
	if point ~= nil then
		local fire = false
		local minSpeed = contactSpeed()
		if not inContact then
			inContact = true
			local rearmed = contactLostAt == nil or (now - contactLostAt) >= CONTACT_REARM_SECONDS
			contactLostAt = nil
			fire = rearmed and speed >= minSpeed
		else
			fire = speed >= minSpeed and (now - lastFire) >= settings.refire
		end
		if fire and now >= cooldownUntil then
			strike(now, speed, point, actor)
		end
	elseif inContact then
		inContact = false
		contactLostAt = now
	end
end

uevr.sdk.callbacks.on_pre_engine_tick(function(engine, delta)
	local ok, err = pcall(tick, os.clock())
	if not ok then log("tick error: " .. tostring(err)) end
end)

uevrUtils.registerPreLevelChangeCallback(function(level)
	--cached actors belong to the old world; addresses get reused
	enemies, breakables, breakableList = {}, {}, {}
	nextEnemyScan, nextBreakableScan = 0, 0
	meshAxisCache = {}
	resetMotion()
	pendingStrike = nil
	if steer.active then endSteer() end
end)

uevr.params.sdk.callbacks.on_script_reset(function()
	pendingStrike = nil
	if steer.active then endSteer() end
end)

return M
