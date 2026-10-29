--[[
IK arms mode for Avowed: a full-arm IK rig (libs/ik) instead of the floating hands, switchable live with the
"Hands Mode" combo. Modelled on the Outer Worlds 2 and Hellraiser profiles (same Obsidian skeleton as OW2:
spine3_JNT, *_shoulder_JNT, *_upperArm_JNT, *_lowerArm_JNT, *_hand_JNT). Lives in scripts/avowed/ (see
physical_melee.lua for why) and is required by main.lua.

Rig meshes: copies of the same game components the hands use (main.lua getCustomHandComponent: the GLOVES layers
and the TORSO sleeves), through ik.lua's getCustomIKComponent hook. Rig settings: data/ik_parameters.json.

Hand calibration (live MCP 2026-10-28): the hands-mode hand meshes sit on the motion controllers with a zero
relative transform, so the r_hand_JNT / l_hand_JNT component-space transform of a hands-mode mesh IS the hand
bone's pose in controller space. Those values are the solvers' end_bone_offset / end_bone_rotation, so an IK hand
lands exactly where the floating hand was.

Weapons: in hands mode attachments sit on the hand mesh, i.e. in controller space. In IK mode each hand gets a proxy
(a hidden sphere, for its culling bounds) on the rig mesh, placed right after the IK solve (same tick) at hand bone * inverse(end bone offset):
the "controller" the IK hand was solved for. The attachments lib grips onto the proxy with the unchanged per-weapon
offsets, so weapons stay locked to the IK hands (no frame of lag) without any re-tuning.
]]--

local uevrUtils = require('libs/uevr_utils')
local controllers = require('libs/controllers')
local configui = require('libs/configui')
local hands = require('libs/hands')
local attachments = require('libs/attachments')
local ik = require('libs/ik')

local M = {}

M.HandsMode = { HANDS = 1, IK = 2 }

-- true shows the IK Dev Config panel (mesh offsets, solver tuning); saves to data/ik_parameters.json
local SHOW_IK_DEV_PANEL = false
local PROXY_TICK_PRIORITY = -1000 -- after ik.lua's solve (priority 0) in the same tick
local IK_PARAMS_FILE = "ik_parameters.json"
local IK_PARAMS_RELOAD_SECONDS = 2.0

local configWidgets = {
	{ widgetType = "combo", id = "hands_mode", label = "Hands Mode", selections = {"Hands", "IK Arms"}, initialValue = M.HandsMode.HANDS },
}

function M.getConfigurationWidgets()
	return configWidgets
end

local handsMode = nil
function M.isIKMode()
	return handsMode == M.HandsMode.IK
end

-- ---------------------------------------------------------------------------------------------
-- Rig meshes
-- ---------------------------------------------------------------------------------------------
-- ik.lua hook (profile mesh "Custom"). The animation keys are the hands_parameters.json profile keys, so the
-- weapon grip / trigger finger poses drive the matching rig copies. Arms comes first: the solvers read bones
-- from the first mesh.
function getCustomIKComponent(rigId)
	if getCustomHandComponent == nil then return {} end
	local templates = { { instance = getCustomHandComponent("Arms"), animation = "Arms" } }
	for _, key in ipairs({"ForeArms", "Gloves2", "Gloves3"}) do
		local component = getCustomHandComponent(key)
		if component ~= nil then
			table.insert(templates, { instance = component, animation = key, optional = true })
		end
	end
	return templates
end

local function haveRigSource()
	return getCustomHandComponent ~= nil and uevrUtils.getValid(getCustomHandComponent("Arms")) ~= nil
end

-- ---------------------------------------------------------------------------------------------
-- End bone calibration (read from ik_parameters.json, so tuning in the IK panel carries over to the weapons)
-- ---------------------------------------------------------------------------------------------
local handBones = {} -- [hand] = { fname, inverseEnd (FTransform) }
local nextParamsReload = 0

local function loadEndBones()
	local ok, params = pcall(json.load_file, IK_PARAMS_FILE)
	if not ok or type(params) ~= "table" then return end
	local profileId = params["_profileState"] and params["_profileState"]["currentEditingProfile"] or "default"
	local profile = params[profileId] or params["default"]
	if profile == nil or type(profile.solvers) ~= "table" then return end
	for _, solver in pairs(profile.solvers) do
		if solver.active ~= false and solver.end_bone ~= nil and solver.end_bone ~= "" then
			local hand = solver.end_control_type == 0 and Handed.Left or Handed.Right
			local loc = solver.end_bone_offset or {0, 0, 0}
			local rot = solver.end_bone_rotation or {0, 0, 0}
			local endTransform = kismet_math_library:MakeTransform(uevrUtils.vector(loc[1], loc[2], loc[3]), uevrUtils.rotator(rot[1], rot[2], rot[3]), uevrUtils.vector(1, 1, 1))
			handBones[hand] = {
				fname = uevrUtils.fname_from_string(solver.end_bone),
				inverseEnd = kismet_math_library:InvertTransform(endTransform),
			}
		end
	end
end

-- ---------------------------------------------------------------------------------------------
-- Weapon proxies
-- ---------------------------------------------------------------------------------------------
local rig = { mesh = nil, tickPhase = nil }
local proxies = {} -- [hand] = SphereComponent

-- The game's weapon meshes have bUseAttachParentBound set (their usual parent is the weapon's BoundsComponent), so
-- they are culled by their parent's bounds. A plain SceneComponent's bounds are a point at the hand, which made the
-- weapon vanish whenever that point left the view. The proxy is a hidden, non-colliding sphere instead, whose bounds
-- cover any weapon held in the hand.
local PROXY_BOUNDS_RADIUS = 200

local function ensureProxy(hand)
	local proxy = uevrUtils.getValid(proxies[hand])
	if proxy == nil then
		proxy = uevrUtils.create_component_of_class("Class /Script/Engine.SphereComponent")
		if proxy ~= nil then
			proxy:SetSphereRadius(PROXY_BOUNDS_RADIUS, false)
			proxy:SetCollisionEnabled(0, false)
			proxy:SetHiddenInGame(true, false) --shape debug drawing; not propagated, the weapons stay visible
		end
		proxies[hand] = proxy
	end
	return proxy
end

local function detachProxies()
	for _, proxy in pairs(proxies) do
		if uevrUtils.getValid(proxy) ~= nil then
			proxy:DetachFromParent(true, false) --keep world: weapons stay put until the next rig takes them
		end
	end
end

-- proxy relative to the rig mesh = inverse(end bone offset) * hand bone (component space): the controller pose
-- the IK hand was solved for. Scale is ignored (hide_body scales the root bone).
local function updateProxies()
	local mesh = rig.mesh
	if mesh == nil or uevrUtils.getValid(mesh) == nil then return end
	for hand, bone in pairs(handBones) do
		local proxy = proxies[hand]
		if proxy ~= nil and uevrUtils.getValid(proxy) ~= nil then
			local boneTransform = mesh:GetBoneTransformByName(bone.fname, EBoneSpaces.ComponentSpace)
			if boneTransform ~= nil then
				boneTransform.Scale3D = uevrUtils.vector(1, 1, 1)
				local rel = kismet_math_library:ComposeTransforms(bone.inverseEnd, boneTransform)
				proxy:K2_SetRelativeLocationAndRotation(rel.Translation, kismet_math_library:Quat_Rotator(rel.Rotation), false, reusable_hit_result, false)
			end
		end
	end
end

local function proxyTick(phase)
	if not M.isIKMode() or rig.mesh == nil or rig.tickPhase ~= phase then return end
	local now = os.clock()
	if now >= nextParamsReload then
		nextParamsReload = now + IK_PARAMS_RELOAD_SECONDS
		loadEndBones()
	end
	updateProxies()
end
uevrUtils.registerPreEngineTickCallback(function() proxyTick("pre") end, PROXY_TICK_PRIORITY)
uevrUtils.registerPostEngineTickCallback(function() proxyTick("post") end, PROXY_TICK_PRIORITY)

-- grip parent for main.lua's attachments grip callback; nil until the rig and its proxies exist
function M.getHandProxy(hand)
	if not M.isIKMode() or rig.mesh == nil then return nil end
	return uevrUtils.getValid(proxies[hand])
end

-- a rebuilt rig starts in the open pose until an input edge; re-assert the weapon grip / trigger poses
local function refreshWeaponPoses()
	for _, ms in ipairs({300, 1200}) do
		delay(ms, function()
			pcall(function()
				hands.updateAnimationState(Handed.Right)
				hands.updateAnimationState(Handed.Left)
			end)
		end)
	end
end

ik.registerOnMeshCreatedCallback(function(meshList, rigInstance)
	for _, mesh in ipairs(meshList or {}) do
		pcall(function() mesh:SetCastShadow(false) end)
	end
	rig.mesh = meshList ~= nil and meshList[1] or nil
	rig.tickPhase = rigInstance ~= nil and rigInstance.tickPhase or "pre"
	if rig.mesh == nil then return end
	loadEndBones()
	for _, hand in ipairs({Handed.Left, Handed.Right}) do
		local proxy = ensureProxy(hand)
		if proxy ~= nil then
			proxy:K2_AttachTo(rig.mesh, uevrUtils.fname_from_string(""), 0, false)
		end
	end
	updateProxies()
	attachments.forceGripUpdate()
	refreshWeaponPoses()
end)

-- runs before ik.lua destroys the rig meshes; their plain-actor children would be destroyed with them
ik.registerOnDestroyCallback(function(rigInstance)
	detachProxies()
	rig.mesh = nil
end)

-- ---------------------------------------------------------------------------------------------
-- Mode switching
-- ---------------------------------------------------------------------------------------------
ik.init(SHOW_IK_DEV_PANEL, LogLevel.Warning)
ik.setAutoCreateArms(false) --ik.lua defaults to true; follows the mode below

-- rebuild the rig from the current outfit (main.lua's mesh-change poll); auto-create rebuilds it within ~1 s
function M.rebuild()
	if ik.exists() then ik.destroyAll() end
end

local function applyHandsMode(mode)
	local changed = handsMode ~= nil and handsMode ~= mode
	handsMode = mode
	if changed then
		--let go of the weapons first so they are not lost with the old hand components
		attachments.detachGripAttachments(Handed.Right)
		attachments.detachGripAttachments(Handed.Left)
	end
	if mode == M.HandsMode.IK then
		hands.setAutoCreateHands(false)
		hands.destroyHands()
		--the solvers need the motion controllers; in hands mode the hands create them
		controllers.createController(0)
		controllers.createController(1)
		controllers.createController(2)
	else
		ik.setAutoCreateArms(false)
		M.rebuild()
		hands.setAutoCreateHands(true)
	end
end

configui.onCreateOrUpdate("hands_mode", function(value)
	--config callbacks can run off the game thread; switch on the next game tick
	delay(1, function() applyHandsMode(value) end)
end)

-- auto-create only once the outfit components exist, so the rig is never built without its arms. The motion
-- controllers are reset on every level change and nothing else recreates them in IK mode.
setInterval(250, function()
	if not M.isIKMode() then return end
	for _, id in ipairs({Handed.Left, Handed.Right}) do
		if controllers.controllerExists(id, true) == false then controllers.createController(id) end
	end
	if controllers.getController(2, true) == nil then controllers.createController(2) end
	ik.setAutoCreateArms(haveRigSource())
end)

uevrUtils.registerPreLevelChangeCallback(function(level)
	rig.mesh = nil
	proxies = {} --their actor belongs to the old world
end)

return M
