local uevrUtils = require('libs/uevr_utils')
local controllers = require('libs/controllers')
local configui = require("libs/configui")
local reticule = require("libs/reticule")
local hands = require('libs/hands')
local attachments = require('libs/attachments')
local input = require('libs/input')
local pawnModule = require('libs/pawn')
local animation = require('libs/animation')
local montage = require('libs/montage')
local interaction = require('libs/interaction')
local ui = require('libs/ui')
local remap = require('libs/remap')
local gestures = require('libs/gestures')
local physicalMelee = require('avowed/physical_melee')
local noLunge = require('avowed/no_lunge')
local ikArms = require('avowed/ik_arms')
local inventoryGesture = require('avowed/inventory_gesture')

ui.init()
montage.init(false) --true shows the Montage config panel (developer configuration); data/montage_parameters.json still applies
interaction.init()
attachments.init(false) --true shows the Attachments + accessories config panels (developer configuration); data/attachments_parameters.json still applies
attachments.setGripUpdateTimeout(200)
reticule.init()
pawnModule.init()
remap.init()
input.init()

attachments.allowChildVisibilityHandling(false)

local versionTxt = "v1.0.1"
local title = "Avowed First Person Mod " .. versionTxt
local configDefinition = {
	{
		panelLabel = "Avowed Config",
		saveFile = "avowed_config",
		layout = spliceableInlineArray
		{
			{ widgetType = "text", id = "title", label = title },
			{ widgetType = "indent", width = 20 }, { widgetType = "text", label = "Input" }, { widgetType = "begin_rect", },
				expandArray(input.getConfigurationWidgets),
			{ widgetType = "end_rect", additionalSize = 12, rounding = 5 }, { widgetType = "unindent", width = 20 },
			{ widgetType = "new_line" },
			{ widgetType = "indent", width = 20 }, { widgetType = "text", label = "UI" }, { widgetType = "begin_rect", },
				expandArray(ui.getConfigurationWidgets),
			{ widgetType = "end_rect", additionalSize = 12, rounding = 5 }, { widgetType = "unindent", width = 20 },
			{ widgetType = "new_line" },
			{ widgetType = "indent", width = 20 }, { widgetType = "text", label = "Reticule" }, { widgetType = "begin_rect", },
				expandArray(reticule.getConfigurationWidgets,{{id="uevr_reticule_update_distance", initialValue=200},}),
				{
					widgetType = "slider_float",
					id = "ret_brightness",
					label = "Reticule Brightness",
					speed = 0.1,
					range = {1.0, 100.0},
					initialValue = 1.0
				},
			{ widgetType = "end_rect", additionalSize = 12, rounding = 5 }, { widgetType = "unindent", width = 20 },
			{ widgetType = "new_line" },
			{ widgetType = "indent", width = 20 }, { widgetType = "text", label = "Options" }, { widgetType = "begin_rect", },
				{
					widgetType = "checkbox",
					id = "full_body_mode",
					label = "Full Body Mode (experimental)",
					initialValue = true
				},
				expandArray(ikArms.getConfigurationWidgets),
				expandArray(inventoryGesture.getConfigurationWidgets),
			{ widgetType = "end_rect", additionalSize = 12, rounding = 5 }, { widgetType = "unindent", width = 20 },
			{ widgetType = "new_line" },
			{ widgetType = "indent", width = 20 }, { widgetType = "text", label = "Shield Block" }, { widgetType = "begin_rect", },
					{
						widgetType = "checkbox",
						id = "shield_block_gesture_enabled",
						label = "Enable Shield Block Gesture",
						initialValue = true
					},
					{
						widgetType = "slider_float",
						id = "shield_block_distance",
						label = "Block Distance (cm)",
						speed = 1.0,
						range = {15, 80},
						initialValue = 35
					},
					{
						widgetType = "slider_float",
						id = "shield_block_scale",
						label = "Shield Size While Blocking",
						speed = 0.01,
						range = {0.3, 1.0},
						initialValue = 0.7
					},
				{ widgetType = "end_rect", additionalSize = 12, rounding = 5 }, { widgetType = "unindent", width = 20 },
				{ widgetType = "new_line" },
			{ widgetType = "indent", width = 20 }, { widgetType = "text", label = "Melee" }, { widgetType = "begin_rect", },
					{
						widgetType = "combo",
						id = "melee_mode",
						label = "Melee Mode",
						selections = {"Swing (swing to attack)", "Physical (weapon must touch the target)"},
						initialValue = 2
					},
					{
						widgetType = "checkbox",
						id = "melee_strong_swing_enabled",
						label = "Enable Strong Attack On Fast Swing",
						initialValue = true
					},
					{
						widgetType = "slider_float",
						id = "melee_strong_swing_threshold",
						label = "Strong Swing Speed Threshold",
						speed = 0.01,
						range = {0.3, 1.0},
						initialValue = 0.75
					},
					{
						widgetType = "slider_float",
						id = "melee_strong_swing_speed_ceiling",
						label = "Strong Swing Speed Ceiling (units/sec)",
						speed = 5.0,
						range = {320, 2000},
						initialValue = 700
					},
					{
						widgetType = "slider_float",
						id = "melee_strong_swing_hold_seconds",
						label = "Strong Attack Hold Duration (s)",
						speed = 0.01,
						range = {0.15, 1.0},
						initialValue = 0.4
					},
					{
						widgetType = "slider_float",
						id = "melee_attack_speed",
						label = "Melee Attack Speed (1 = game default)",
						speed = 0.1,
						range = {1.0, 10.0},
						initialValue = 3.0
					},
					{
						widgetType = "slider_float",
						id = "melee_swing_attack_speed",
						label = "Melee Attack Speed (1 = game default)##swing",
						speed = 0.1,
						range = {1.0, 10.0},
						initialValue = 10.0
					},
					expandArray(noLunge.getConfigurationWidgets),
					expandArray(physicalMelee.getConfigurationWidgets),
				{ widgetType = "end_rect", additionalSize = 12, rounding = 5 }, { widgetType = "unindent", width = 20 },
				{ widgetType = "new_line" },
				{ widgetType = "indent", width = 20 }, { widgetType = "text", label = "Settings" }, { widgetType = "begin_rect", },
				{
					widgetType = "checkbox",
					id = "enable_lumen",
					label = "Enable Lumen",
					initialValue = true
				},
			{ widgetType = "end_rect", additionalSize = 12, rounding = 5 }, { widgetType = "unindent", width = 20 },
			{ widgetType = "new_line" },
		}
	}
}
configui.create(configDefinition)

--configui.create loads the saved values and fires the callbacks registered so far; callbacks registered after it
--(everything below) would only see later changes, so saved settings never applied until their slider was moved.
--This registers the callback and runs it once with the loaded value.
local function onConfigValue(widgetID, func)
    configui.onCreateOrUpdate(widgetID, func)
    local value = configui.getValue(widgetID)
    if value ~= nil then func(value) end
end

local status = {}

local function isFullBodyMode()
    if pawn ~= nil then
       return not pawn:BP_GetIsFirstPerson()
    end
end

--Courtesy of markmon
local function toggle_lumen(enabled)
    set_cvar_int("r.Lumen.DiffuseIndirect.Allow", enabled)
    if enabled == 1 then
        set_cvar_float("r.TonemapperGamma", 0.0)
    else
        set_cvar_float("r.TonemapperGamma", 1.5)
    end
end

configui.onCreateOrUpdate("full_body_mode", function(value)
    if pawn ~= nil then
        local isFP = pawn:BP_GetIsFirstPerson()
        if isFP == value then
            uevr.api:get_player_controller(0):ToggleIsFirstPerson()
        end
    end
end)

onConfigValue("enable_lumen", function(value)
    toggle_lumen(value and 1 or 0)
end)

--Shield block gesture, ported from backup 1.1 (Avowed6dof.lua GetBlock/SHIELD_BLOCK_SIZE).
--Raising the shield hand close to the headset triggers a block and shrinks the shield, same as 1.1,
--but reimplemented on top of the current attachment/config system instead of a fixed weapon-name scale.
local shieldBlockGestureEnabled = true
local shieldBlockDistance = 35
local shieldBlockScaleRatio = 0.7
onConfigValue("shield_block_gesture_enabled", function(value) shieldBlockGestureEnabled = value end)
onConfigValue("shield_block_distance", function(value) shieldBlockDistance = value end)
onConfigValue("shield_block_scale", function(value) shieldBlockScaleRatio = value end)

local shieldBlockState = {
    attachment = nil,  --the currently gripped shield attachment component, if any
    baseScale = nil,   --its configured (non-blocking) RelativeScale3D, captured on equip
    isBlocking = false,
}

local function getShieldHandDistanceFromHead()
    local hmdController = controllers.getController(2, true)
    if hmdController == nil then return nil end
    return controllers.getDistanceFromController(Handed.Left, hmdController)
end

local function applyShieldScale(scaleMultiplier)
    if uevrUtils.getValid(shieldBlockState.attachment) ~= nil and shieldBlockState.baseScale ~= nil then
        uevrUtils.set_component_relative_scale(shieldBlockState.attachment, uevrUtils.vector(
            shieldBlockState.baseScale.X * scaleMultiplier,
            shieldBlockState.baseScale.Y * scaleMultiplier,
            shieldBlockState.baseScale.Z * scaleMultiplier
        ))
    end
end

local function setShieldBlocking(isBlocking)
    if shieldBlockState.isBlocking == isBlocking then return end
    shieldBlockState.isBlocking = isBlocking
    applyShieldScale(isBlocking and shieldBlockScaleRatio or 1.0)
end

--Strong melee attack via a fast swing. In the flat game, a strong attack is done by holding the
--attack trigger and releasing it (confirmed live via UEVR MCP: the equipped weapon's ability is
--GameplayAbility_PlayerWeaponAction, which has separate PressMontage/QuickReleaseMontage/HoldReleaseMontage
--and a native Event_InputReleased(TimeHeld) that decides which montage plays based on how long the
--input was held before release). A single-frame trigger pulse can only ever produce a quick release.
--A fast/strong swing is used here as the "hold" signal instead: rather than pulsing the trigger for
--one frame, it's held across several frames for a configurable duration and then let go, so the
--ability sees the same press-hold-release shape a physical hold would produce.
local strongSwingHold = {
    holding = false,
    startTime = nil,
}
local meleeStrongSwingEnabled = true
local meleeStrongSwingThreshold = 0.75
local meleeStrongSwingHoldSeconds = 0.4
onConfigValue("melee_strong_swing_enabled", function(value) meleeStrongSwingEnabled = value end)
onConfigValue("melee_strong_swing_threshold", function(value) meleeStrongSwingThreshold = value end)
onConfigValue("melee_strong_swing_hold_seconds", function(value) meleeStrongSwingHoldSeconds = value end)
--maxThresholdSpeed=320 (gestures.lua's stock default) saturates strength to ~1.0 on almost any real
--swing, since a normal swing's peak speed already clears it easily - this raises the ceiling so the
--threshold slider above actually has range to discriminate a fast swing from a normal one.
onConfigValue("melee_strong_swing_speed_ceiling", function(value) gestures.setSwipeStrengthCeiling(value) end)

--some of the montages try to take over the camera which causes a flickering in the left eye.  This compensates for that behavior
local yawMontages = {AM_1P_CloseSingleDoor_Push_R = 1000, AM_1P_CloseSingleDoor_Pull_R = 1000, AM_NPC_Ladder_Climb_Down_Intro = 1000,AM_UNI_1P_PullUp_32_In2Crouch = 1200, AM_1P_SingleDoor_Unbar = 3000, AM_1P_WallLever_Up = 3000, AM_1P_WallLever_Down = 3000, AM_UNI_1P_PushUp20_In2Crouch = 1000, AM_Uni_Container_Medium_Open = 3500, AM_Uni_DoubleDoor_Open_F = 1500, AM_Uni_DoubleDoor_Open_B = 1500, AM_1P_OpenSingleDoor_L = 1500, AM_1P_OpenSingleDoor_R = 1000,AM_Container_Large_Wide_Open = 4000, AM_Container_Large_Default_Open = 4000} -- AM_UNI_1P_Parkour_Mantle_120 = 700, AM_UNI_1P_Parkour_Mantle_315 = 1200, AM_UNI_1P_Parkour_Vault_200 = 1000, AM_UNI_1P_Parkour_Vault_300 = 1000}
function on_montage_change(montageObject, montageName)
    if status["activeYawMontage"] ~= nil then
        delay(500, function()
            --dont disable the previous one if a new one has started
            if status["activeYawMontage"] == nil then
                input.setDisabled(false)
            end
        end)
        status["activeYawMontage"] = nil
    elseif yawMontages[montageName] ~= nil then
        input.setDisabled(true)
        status["activeYawMontage"] = montageName
    end
end

local function onIsClimbingLadderChange(isClimbing)
    if isClimbing then
        if isFullBodyMode() then
            status["ladderPawnRotationMode"] = input.getPawnRotationMode()
            input.setPawnRotationMode(input.PawnRotationMode.NONE)
            input.setOptimizeBodyYawCalculations(false)
        else
            input.setDisabled(true)
        end
    else
        delay(500, function()
            if isFullBodyMode() then
                input.setPawnRotationMode(status["ladderPawnRotationMode"])
                input.setOptimizeBodyYawCalculations(true)
                status["ladderPawnRotationMode"] = nil
            else
                input.setDisabled(false)
            end
        end)
    end
end

local function getChildFromSkeletalMeshName(parent, name)
	if uevrUtils.validate_object(parent) ~= nil and name ~= nil then
		local children = parent.AttachChildren
		if children ~= nil then
			for i, child in ipairs(children) do
				if child.SkeletalMesh ~= nil and string.find(child.SkeletalMesh:get_full_name(), name) then
					return child
				end
			end
		end
	end
	return nil
end

local function getChildrenFromSkeletalMeshName(parent, name)
    local result = {}
	if uevrUtils.validate_object(parent) ~= nil and name ~= nil then
		local children = parent.AttachChildren
		if children ~= nil then
			for i, child in ipairs(children) do
				if child.SkeletalMesh ~= nil and string.find(child.SkeletalMesh:get_full_name(), name) then
					table.insert(result, child)
				end
			end
		end
	end
	return result
end

-- A single glove can have many glove meshes. 
-- For example, Vambraces have 3 separate meshes, one for nude hands and two for the bracers themselves.
-- This structure keeps track of the different glove meshes and returns the correct one when requested.
local handMeshes = {
    initialized = false,
    meshes = {},
	init = function(self, parent)
        local foundMeshes = getChildrenFromSkeletalMeshName(parent, "GLOVES")
        --look for one with "Nude/" in the name first. If that exists make it the hands mesh and remove it
        --from the list. Then assign the others to glove2Mesh and glove3Mesh if they exist.
        --If no nude mesh is found, then assign the first to handsMesh, second to glove2Mesh, third to glove3Mesh.
        for i, mesh in ipairs(foundMeshes) do
            if string.find(mesh.SkeletalMesh:get_full_name(), "Nude/") then
                self.meshes["Arms"] = mesh
                table.remove(foundMeshes, i)
                break
            end
        end
        if self.meshes["Arms"] == nil and #foundMeshes >= 1 then
            self.meshes["Arms"] = foundMeshes[1]
            table.remove(foundMeshes, 1)
        end
        if #foundMeshes >= 1 then
            self.meshes["Gloves2"] = foundMeshes[1]
            table.remove(foundMeshes, 1)
        end
        if #foundMeshes >= 1 then
            self.meshes["Gloves3"] = foundMeshes[1]
            table.remove(foundMeshes, 1)
        end
    end,
	get = function(self, parent, name) -- "Arms" or "Gloves2" or "Gloves3"
        if self.initialized == false then
            self:init(parent)
            self.initialized = true
        end
        return self.meshes[name]
    end,
    reset = function(self)
        self.initialized = false
        self.meshes = {}
    end,
}

function getCustomHandComponent(key)
    local meshName = isFullBodyMode() and "Mesh" or "FirstPersonSkelMesh"
    --print("Getting custom hand component for key: " .. tostring(key))
    if key == "ForeArms" then
        return getChildFromSkeletalMeshName(uevrUtils.getValid(pawn,{"FirstPersonSkelMesh"}), "TORSO") --Pawn.FirstPersonSkelMesh(PoseableMeshComponent_2147479490)
    else
        return handMeshes:get(uevrUtils.getValid(pawn,{meshName}), key)
    end
end

--return true if arm bones should be hidden
pawnModule.registerIsArmBonesHiddenCallback(function()
    local hideArmBones = nil
    if uevrUtils.getValid(pawn) ~= nil and pawn:IsSwimming() or status["isClimbingLadder"] then
        hideArmBones = false
    end
	return hideArmBones, 0
end)

--return true if hands should be hidden, second param is priority
hands.registerIsHiddenCallback(function()
    local hideHands = nil
    if uevrUtils.getValid(pawn) ~= nil and pawn:IsSwimming() or status["isClimbingLadder"] then
        hideHands = true
    end
	return hideHands, 0
end)

local function getWeaponMesh(slot)
    if uevrUtils.getValid(pawn) == nil then
        return nil, nil
    end
    local weapon = pawn:GetEquippedActorFromSlotInActiveLoadout(uevrUtils.tagFromString(slot))
    if weapon == nil or weapon:IsUnsheathed() == false then
        return nil, nil
    end

    return weapon and weapon:GetBaseMesh(), weapon
end

attachments.registerOnGripUpdateCallback(function()
    status["currentWeaponRight"] = nil
    status["currentWeaponLeft"] = nil
    status["currentWeaponActorRight"] = nil
    status["currentWeaponActorLeft"] = nil

    if uevrUtils.isInCutscene() then return end
    --if not allowWeapon then return end

    local currentWeaponRight, currentWeaponActorRight = getWeaponMesh("EquipSlot.RightHand")
    local currentWeaponLeft, currentWeaponActorLeft = getWeaponMesh("EquipSlot.LeftHand")

    --if its a bow then make left the primary hand
    if currentWeaponRight and string.find(currentWeaponRight:get_full_name(), "2H_Bow")  then
        currentWeaponLeft = currentWeaponRight
        currentWeaponRight = nil
    end

    status["currentWeaponRight"] = currentWeaponRight
    status["currentWeaponLeft"] = currentWeaponLeft
    status["currentWeaponActorRight"] = currentWeaponActorRight
    status["currentWeaponActorLeft"] = currentWeaponActorLeft

    --a montage set to "Detach to Pawn" (Montage Config, Attachments): returning nothing releases the grips, and the
    --lib puts each weapon back on its original game socket with its original transform (reattach options below)
    if status["montageDetachesAttachments"] then return end

    --IK arms mode: the weapons go on per-hand proxies that ride the IK hands (avowed/ik_arms.lua)
    local rightParent = ikArms.isIKMode() and ikArms.getHandProxy(Handed.Right) or hands.getHandComponent(Handed.Right, "Arms")
    local leftParent = ikArms.isIKMode() and ikArms.getHandProxy(Handed.Left) or hands.getHandComponent(Handed.Left, "Arms")
    if rightParent == nil or leftParent == nil then
        return
    end
    return currentWeaponRight, rightParent, nil, currentWeaponLeft, leftParent, nil, true, true
 end)

--Montage Config "Attachments" row: while a montage set to Detach to Pawn plays, the grip callback above returns
--nothing (weapons back on the pawn); when it ends, the next grip update puts whatever is equipped back in the hands
montage.onUpdate("attachments", function(value)
    status["montageDetachesAttachments"] = value == true
    delay(1, function() attachments.forceGripUpdate() end)
end)
--Montage Config "Left / Right Attachment Visibility" rows: Hidden hides whatever that hand grips for the montage.
--SetHiddenInGame, not SetVisibility: the hands / IK rig hide propagates SetVisibility to their children (the
--weapons), so the two flags never undo each other. Re-checked on an interval so a weapon gripped mid-montage is
--hidden too; each hidden component gets its own previous state back.
local attachmentHiding = {
    [Handed.Left] = { stateKey = "leftAttachment", active = false, hidden = {} }, --hidden: address -> { component, wasHidden }
    [Handed.Right] = { stateKey = "rightAttachment", active = false, hidden = {} },
}
local function hideAttachment(hand)
    local attachment = uevrUtils.getValid(attachments.getCurrentGrippedAttachment(hand))
    if attachment == nil then return end
    local hidden = attachmentHiding[hand].hidden
    local key = attachment:get_address()
    if hidden[key] == nil then
        hidden[key] = { component = attachment, wasHidden = attachment.bHiddenInGame == true }
    end
    if attachment.bHiddenInGame ~= true then attachment:SetHiddenInGame(true, true) end
end
local function restoreAttachments(hand)
    for _, entry in pairs(attachmentHiding[hand].hidden) do
        if uevrUtils.getValid(entry.component) ~= nil then entry.component:SetHiddenInGame(entry.wasHidden, true) end
    end
    attachmentHiding[hand].hidden = {}
end
for hand, hiding in pairs(attachmentHiding) do
    montage.onUpdate(hiding.stateKey, function(value)
        hiding.active = value == true
        delay(1, function()
            if hiding.active then hideAttachment(hand) else restoreAttachments(hand) end
        end)
    end)
end
setInterval(100, function()
    for hand, hiding in pairs(attachmentHiding) do
        if hiding.active then hideAttachment(hand) end
    end
end)

uevrUtils.registerPreLevelChangeCallback(function(level)
    status["montageDetachesAttachments"] = false
    for _, hiding in pairs(attachmentHiding) do
        hiding.active = false
        hiding.hidden = {} --old-world components
    end
end)

local function setDefaultTargeting(handed, offset)
	if handed == Handed.Left then
		input.setAimMethod(input.AimMethod.LEFT_CONTROLLER)
	else
		input.setAimMethod(input.AimMethod.RIGHT_CONTROLLER)
	end
end

local function setMeleeOffset(hand)
    local offset = attachments.getActiveAttachmentMeleeRotationOffset(hand)
    if offset then
        input.setAimRotationOffset(offset)
        uevrUtils.updateDeferral("melee_attack")
    end
end

--won't callback unless an updateDeferral hasnt been called in the last 1000ms
uevrUtils.createDeferral("melee_attack", 1000, function()
    input.setAimRotationOffset({Pitch=0, Yaw=0, Roll=0})
end)

local function getNiagaraChildren(parent)
    local result = {}
	if uevrUtils.validate_object(parent) ~= nil  then
		local children = parent.AttachChildren
		if children ~= nil then
			for i, child in ipairs(children) do
				if child:is_a(uevrUtils.get_class("Class /Script/Niagara.NiagaraComponent")) then
					table.insert(result, child)
				end
			end
		end
	end
	return result
end

--this is used for grimoire spells
local currentNiagaraChildren = {}
setInterval(100, function()
    local meshName = isFullBodyMode() and "Mesh" or "FirstPersonSkelMesh"
    local niagaraChildren = getNiagaraChildren(uevrUtils.getValid(pawn,{meshName}))
    if #niagaraChildren > 0 then
        print("Found " .. #niagaraChildren .. " niagara children attached to hand mesh.")
    end
    --add any new niagara components to attachments and remove any that existed before but are now gone
    for i, child in ipairs(niagaraChildren) do
        local found = false
        for j, existingChild in ipairs(currentNiagaraChildren) do
            if existingChild == child then
                found = true
                break
            end
        end
        if not found then
            setDefaultTargeting(Handed.Right) --grimoire spells fire from the right hand
            if child.AttachSocketName:to_string() == "l_weapon_NSKSocket" or child.AttachSocketName:to_string() == "hand_lSocket" then
                print("Attaching niagara component to left controller: " .. child:get_full_name(), child.AttachSocketName)
                attachments.attachToMesh(child, controllers.getController(Handed.Left))
            else
                print("Attaching new niagara component to right controller: " .. child:get_full_name(), child.AttachSocketName)
                attachments.attachToMesh(child, controllers.getController(Handed.Right))
            end
        end
    end
    currentNiagaraChildren = niagaraChildren
end)


--Outfit signature: every GLOVES layer and the TORSO sleeves the hands / IK rig are copied from (component and asset),
--so swapping gloves or chest armour rebuilds them
local function getOutfitSignature()
    local meshName = isFullBodyMode() and "Mesh" or "FirstPersonSkelMesh"
    local parts = {}
    for _, child in ipairs(getChildrenFromSkeletalMeshName(uevrUtils.getValid(pawn,{meshName}), "GLOVES")) do
        table.insert(parts, tostring(child:get_address()) .. "=" .. child.SkeletalMesh:get_full_name())
    end
    local torso = getChildFromSkeletalMeshName(uevrUtils.getValid(pawn,{"FirstPersonSkelMesh"}), "TORSO")
    if torso ~= nil then
        table.insert(parts, tostring(torso:get_address()) .. "=" .. torso.SkeletalMesh:get_full_name())
    end
    return table.concat(parts, "|")
end

setInterval(1000, function()
    --check if the pawns hands mesh has changed and if so, destroy ours so they will regenrate with the new mesh
    local outfit = getOutfitSignature()
    if status["currentOutfit"] ~= outfit then
        status["currentOutfit"] = outfit
        --print("Hand mesh changed, destroying existing hands and resetting.")
        handMeshes:reset()
        if ikArms.isIKMode() then
            ikArms.rebuild()
        else
            hands.destroyHands()
        end
    end

    if status["currentWeaponLeft"] == nil and status["currentWeaponRight"] == nil then
        reticule.setActiveReticuleByLabel("Unarmed Reticule")
    else
        --reticule.setActiveReticuleByLabel("Weapon Reticule")
    end
end)

--Reticule colour and brightness, same approach as the Hellraiser and Cronos profiles.
--White: the crosshair widget is drawn into an 8-bit render target, so a ColorAndOpacity of 10 clips its images to
--pure white (the widget's own colour can't make it brighter than that). Brightness: the 3D component's tint is applied
--in its material and isn't clipped, so values above 1 really brighten. Re-applied on an interval because the reticule
--component is rebuilt whenever a weapon is drawn or sheathed.
local reticuleBrightness = 1.0
onConfigValue("ret_brightness", function(value) reticuleBrightness = value end)
local RETICULE_WIDGET_WHITE = 10.0
setInterval(250, function()
    local component = uevrUtils.getValid(reticule.getComponent())
    if component == nil or component.SetTintColorAndOpacity == nil then return end
    local tint = component.TintColorAndOpacity
    if tint == nil or math.abs(tint.R - reticuleBrightness) > 0.001 then
        component:SetTintColorAndOpacity(uevrUtils.color_from_rgba(reticuleBrightness, reticuleBrightness, reticuleBrightness, 1.0))
    end
    local widget = component.GetWidget ~= nil and uevrUtils.getValid(component:GetWidget()) or nil
    if widget ~= nil and widget.SetColorAndOpacity ~= nil then
        local color = widget.ColorAndOpacity
        if color == nil or color.R ~= RETICULE_WIDGET_WHITE then
            widget:SetColorAndOpacity(uevrUtils.color_from_rgba(RETICULE_WIDGET_WHITE, RETICULE_WIDGET_WHITE, RETICULE_WIDGET_WHITE, 1.0))
        end
    end
end)

local function hideThirdPersonHead(value)
    local children = uevrUtils.getValid(pawn, {"Mesh", "AttachChildren"})
    if children ~= nil then
---@diagnostic disable-next-line: param-type-mismatch
        for i, child in ipairs(children) do
            if child.SkeletalMesh ~= nil then
                local meshName = child.SkeletalMesh:get_full_name()
                if string.find(meshName, "HEAD/HUMAN") or string.find(meshName, "HEAD/GODLIKE") or string.find(meshName, "HEAD/HAIR") or string.find(meshName, "HEAD/FACIALHAIR") then
                    child:SetRenderInMainPass(not value)
                    child:SetRenderInDepthPass(not value)
                    --child:SetVisibility(not value, false)
                    --child:SetHiddenInGame(value, false)
                end
             end
        end
    end
end

local function handleFullBody()
    if uevrUtils.getValid(pawn) ~= nil then
        local isInCutscene = uevrUtils.isInCutscene()
        local isFP = pawn:BP_GetIsFirstPerson()
        --print("Is full body = ", not isFP)
        configui.setValue("full_body_mode", not isFP, true)
        hideThirdPersonHead(not isFP and not isInCutscene)
        pawnModule.setCurrentProfileByLabel(isFP and "Default" or "Full Body")
        input.setCurrentProfileByLabel(isFP and "Default" or "Full Body")
        if not isFP then
            pawnModule.hideArmsBones(not isInCutscene)
        end
    else --if the pawn isnt ready then keep trying until it is
        delay(1000, function()
            handleFullBody()
        end)
    end
end

local function resetTransform(component)
    --print("Resetting transform for component: " .. component:get_full_name())
    delay(300,function()
        --print("Applying reset transform for component: " .. component:get_full_name())     
        if uevrUtils.getValid(component) ~= nil and component.AttachParent ~= nil then
            component = component.AttachParent
            uevrUtils.set_component_relative_location(component, uevrUtils.vector(0,0,0))
            uevrUtils.set_component_relative_rotation(component, uevrUtils.rotator(0,0,0))
            uevrUtils.set_component_relative_scale(component, uevrUtils.vector(1,1,1))
        end
    end)
end
function on_cutscene_change(isInCinematic)
    handleFullBody()

    --normally when attachments detach they reset their transform, but during cinematics there is
    --some disconnect because the weapons parant is changing during the transition (from hand to holstered). 
    --Using a short delay we reset the new parent's transforms so that the weapon displays correctly during the cinematic
    if isInCinematic then
        if status["currentWeaponRight"] ~= nil then
            resetTransform(status["currentWeaponRight"])
        end
        if status["currentWeaponLeft"] ~= nil then
            resetTransform(status["currentWeaponLeft"])
        end
    end
end

--Melee attack speed (originally a fixed 10, courtesy of markmon: weapon hits react faster, improving feedback).
--AttackSpeedMult also scales the attack's hold-to-charge wind-up and combo windows: at 10 the strong-attack
--threshold was reached in the same tick the hold started (any trigger press became a strong attack) and the combo
--never got past its first step. 1 is the game's own value; at 1 nothing is written, so gear/perk speed buffs stay.
--Tested with hooks 2026-10-28: at 3 taps = quick, holds = strong, combo 01-04 with hits; 3 is the default.
--Each melee mode has its own speed: Swing defaults to the original 10 (with its side effects), Physical to 3.
local MeleeMode = { SWING = 1, PHYSICAL = 2 }
local meleeMode = MeleeMode.PHYSICAL
local meleeAttackSpeeds = { [MeleeMode.SWING] = 10.0, [MeleeMode.PHYSICAL] = 3.0 }
local speedOverridden = {} --weapon actor address -> true while its AttackSpeedMult holds our value
local function applyMeleeAttackSpeed(hand)
    local weapon = hand == Handed.Right and status["currentWeaponActorRight"] or status["currentWeaponActorLeft"]
    if weapon == nil or not attachments.isActiveAttachmentMelee(hand) then return end
    if uevrUtils.getValid(weapon, {"AttackAttributeSet","AttackSpeedMult"}) == nil then return end
    local speed = weapon.AttackAttributeSet.AttackSpeedMult
    if speed.BaseValue == nil or speed.CurrentValue == nil then return end
    local key = weapon:get_address()
    local meleeAttackSpeed = meleeAttackSpeeds[meleeMode]
    if meleeAttackSpeed == 1.0 and not speedOverridden[key] then return end
    speed.BaseValue = meleeAttackSpeed
    speed.CurrentValue = meleeAttackSpeed
    speedOverridden[key] = meleeAttackSpeed ~= 1.0 or nil
end
local function applyMeleeAttackSpeeds()
    --config callbacks can run off the game thread; write the weapon from the next game tick
    delay(1, function()
        applyMeleeAttackSpeed(Handed.Right)
        applyMeleeAttackSpeed(Handed.Left)
    end)
end
onConfigValue("melee_attack_speed", function(value)
    meleeAttackSpeeds[MeleeMode.PHYSICAL] = value
    applyMeleeAttackSpeeds()
end)
onConfigValue("melee_swing_attack_speed", function(value)
    meleeAttackSpeeds[MeleeMode.SWING] = value
    applyMeleeAttackSpeeds()
end)
uevrUtils.registerPreLevelChangeCallback(function(level)
    speedOverridden = {} --old-world actors; addresses get reused
end)

--Melee mode: Swing (the original: a right- or left-hand swing fires the attack) or Physical (the right-hand weapon
--has to touch the target, avowed/physical_melee.lua). Attack speed and lunges are kept per mode; the panel shows
--only the active mode's settings.
local noLungeByMode = { [MeleeMode.SWING] = false, [MeleeMode.PHYSICAL] = true }
local function applyMeleeMode()
    local isPhysical = meleeMode == MeleeMode.PHYSICAL
    physicalMelee.setEnabled(isPhysical)
    noLunge.setEnabled(noLungeByMode[meleeMode])
    configui.setHidden("melee_attack_speed", not isPhysical)
    configui.setHidden("melee_no_lunge", not isPhysical)
    configui.setHidden("melee_swing_attack_speed", isPhysical)
    configui.setHidden("melee_swing_no_lunge", isPhysical)
    for _, widget in ipairs(physicalMelee.getConfigurationWidgets()) do
        configui.setHidden(widget.id, not isPhysical)
    end
    applyMeleeAttackSpeeds()
end
onConfigValue("melee_mode", function(value)
    meleeMode = value == MeleeMode.SWING and MeleeMode.SWING or MeleeMode.PHYSICAL
    delay(1, applyMeleeMode)
end)
onConfigValue("melee_no_lunge", function(value)
    noLungeByMode[MeleeMode.PHYSICAL] = value ~= false
    delay(1, applyMeleeMode)
end)
onConfigValue("melee_swing_no_lunge", function(value)
    noLungeByMode[MeleeMode.SWING] = value ~= false
    delay(1, applyMeleeMode)
end)

--Melee swipe detection is polled directly (see the on_pre_engine_tick below) instead of through
--gestures.lua's autoDetect/callback system, because that system fires the left/right and up/down
--classifications as separate callbacks in the same tick - by the time a left/right callback runs
--there's no way to know yet whether the same swing was also classified as "up", which is needed to
--exclude upward swings from triggering melee. meleeGestureActive gates the poll per hand so it still
--only runs while that hand actually holds something melee-flagged (same perf reasoning as before).
local meleeGestureActive = { [Handed.Right] = false, [Handed.Left] = false }

attachments.registerAttachmentChangeCallback(function(id, hand, attachment)
	-- Reduces processing when no melee weapon is equipped
    meleeGestureActive[Handed.Right] = attachments.isActiveAttachmentMelee(Handed.Right)
    meleeGestureActive[Handed.Left] = attachments.isActiveAttachmentMelee(Handed.Left)

    --newer uevrlib also fires this on release, with id "" and no attachment. Only the per-hand state
    --above and the shield tracking below apply; the reticule falls back to unarmed on its own interval.
    if attachment == nil then
        if hand == Handed.Left then
            shieldBlockState.attachment = nil
            shieldBlockState.baseScale = nil
            shieldBlockState.isBlocking = false
        end
        return
    end

    reticule.setActiveReticuleByLabel("Weapon Reticule", true)

    applyMeleeAttackSpeed(hand)

    --Fix shield Z fighting
    if string.find(id, "Shield") then
      if attachment.AttachChildren ~= nil and #attachment.AttachChildren > 0 then
            for i, child in ipairs(attachment.AttachChildren) do
                if child:is_a(uevrUtils.get_class("Class /Script/Engine.StaticMeshComponent")) then
                    child:SetHiddenInGame(false, false)
                    child:SetVisibility(true, false)
                    child.RelativeScale3D = uevrUtils.vector(0.990, 0.990, 0.990)
                end
            end
        end
    end

    --Track the shield attachment so the block gesture can shrink/restore it. Only ever tracked in
    --the left hand since shield block state (leftHandIsBlocking) is inherently left-hand based.
    if hand == Handed.Left then
        if string.find(id, "Shield") then
            local _, _, baseScale = attachments.getAttachmentOffset(attachment)
            shieldBlockState.attachment = attachment
            shieldBlockState.baseScale = baseScale
            shieldBlockState.isBlocking = false
        else
            shieldBlockState.attachment = nil
            shieldBlockState.baseScale = nil
            shieldBlockState.isBlocking = false
        end
    end
end)


--steering: physical melee is aiming the hit at what the weapon touched, so the per-weapon melee offset stays off
local function onMeleeSwipeDetected(strength, hand, steering)
    if hand == Handed.Right then
        setDefaultTargeting(Handed.Right)
        if not steering then setMeleeOffset(Handed.Right) end
    else
        setDefaultTargeting(Handed.Left)
        if not steering then setMeleeOffset(Handed.Left) end
    end

    if meleeStrongSwingEnabled and strength ~= nil and strength >= meleeStrongSwingThreshold then
        --a fast/strong swing: hold the trigger for a bit instead of a single-frame tap
        strongSwingHold.holding = true
        strongSwingHold.startTime = os.clock()
    elseif hand == Handed.Right then
        status["hasSwipeRight"] = true
    else
        status["hasSwipeLeft"] = true
    end
end

--Physical melee (avowed/physical_melee.lua) strikes when the right-hand weapon touches a target
physicalMelee.setStrikeCallback(function(strength, hand, steering)
    onMeleeSwipeDetected(strength, hand, steering)
end)

--Polls swing classification directly so left/right/up/down are all known together, letting us
--exclude upward swings from counting as a melee attack (left, right, and down all still count).
--With physical melee on, a right-hand swing only attacks through contact; the detector keeps running so its
--history stays current if physical melee is switched off.
uevr.sdk.callbacks.on_pre_engine_tick(function(engine, delta)
    for _, hand in ipairs({Handed.Right, Handed.Left}) do
        if meleeGestureActive[hand] then
            local left, right, up, down, punch, snatch, strength = gestures.getSwipeGestures(delta, hand)
            if (left or right) and not up and not (hand == Handed.Right and physicalMelee.isActive()) then
                onMeleeSwipeDetected(strength, hand)
            end
        end
    end
end)

--wont callback unless an uevrUtils.updateDeferral("is_blocking") hasnt been called in the last 1000ms
uevrUtils.createDeferral("is_blocking", 1000, function()
    status["leftHandIsBlocking"] = false
    setShieldBlocking(false)
end)

uevrUtils.registerOnPreInputGetStateCallback(function(retval, user_index, state)

    if uevrUtils.isButtonPressed(state,XINPUT_GAMEPAD_X) then
        setDefaultTargeting(Handed.RIGHT)
    elseif state.Gamepad.bRightTrigger > 0 and status["currentWeaponLeft"] ~= nil and string.find(status["currentWeaponLeft"]:get_full_name(), "2H_Bow") then
        setDefaultTargeting(Handed.Left)
    else
        --used to stop left hand from targettting when blocking
        if uevrUtils.getValid(pawn) ~= nil then
            local isBlocking = pawn:IsAttemptingToBlock()

            --shield block gesture, ported from backup 1.1: raising the shield hand near the headset
            --also counts as blocking, injecting the trigger the same way a detected swipe does below
            if not isBlocking and shieldBlockGestureEnabled and uevrUtils.getValid(shieldBlockState.attachment) ~= nil then
                local distance = getShieldHandDistanceFromHead()
                if distance ~= nil and distance <= shieldBlockDistance then
                    isBlocking = true
                    state.Gamepad.bLeftTrigger = 255
                end
            end

            if isBlocking then
                status["leftHandIsBlocking"] = true
                uevrUtils.updateDeferral("is_blocking")
                setShieldBlocking(true)
            end
        end

        if state.Gamepad.bRightTrigger > 0 or uevrUtils.isButtonPressed(state, XINPUT_GAMEPAD_RIGHT_SHOULDER) then
            setDefaultTargeting(Handed.Right)
        elseif status["leftHandIsBlocking"] ~= true and state.Gamepad.bLeftTrigger > 0 or uevrUtils.isButtonPressed(state, XINPUT_GAMEPAD_LEFT_SHOULDER) then
            setDefaultTargeting(Handed.Left)
        end
    end

    if strongSwingHold.holding then
        --print("Holding trigger for strong attack, elapsed: " .. tostring(os.clock() - strongSwingHold.startTime))
        if os.clock() - strongSwingHold.startTime < meleeStrongSwingHoldSeconds then
            state.Gamepad.bRightTrigger = 255
        else
            strongSwingHold.holding = false --let go this frame so the game sees a press-hold-release
        end
    end

    if status["hasSwipeRight"] then
        --print("Processing right swipe gesture into input")
        state.Gamepad.bRightTrigger = 255
        status["hasSwipeRight"] = false
    end
	if status["hasSwipeLeft"] then
        --print("Processing left swipe gesture into input")
        state.Gamepad.bRightTrigger = 255
        status["hasSwipeLeft"] = false
    end

end, 5) --increased priority to get values before remap occurs

uevrUtils.registerLevelChangeCallback(function()

    hook_function("BlueprintGeneratedClass /Game/Blueprints/Characters/Player/BPC_AlabamaPlayer.BPC_AlabamaPlayer_C", "BP_OnFirstPersonChanged", false, nil,
		function(fn, obj, locals, result)
            handleFullBody()
		end
	, true)

    handleFullBody()
    handMeshes:reset()
end)

--Custom  method of getting top level UI widgets since WidgetBlueprintLibrary:GetAllWidgetsOfClass doesnt do the job in this game
--I dont like polling for objects, even every second, but hooking the native functions that are required
--to do it the right way, simply doesn't work. Native functions lock up the whole game after a level change.
--The number of objects returned is small, < 20 usually, so performance impact should be minimal.
local screenWidgets = {}
setInterval(1000, function()
    local widgets = uevrUtils.find_all_instances("Class /Script/UiSystem.ScreenWidget", false)
    local currentWidgets = {}

    if widgets ~= nil then
        -- Build a map of currently found widgets with their shown state
        pcall(function()
            for i, widget in ipairs(widgets) do
                local widgetKey = tostring(widget) --keys look like sol.uevr::API::UObject*: 00000233A4B9FEA8
                local isShown = widget:IsShown()
                currentWidgets[widgetKey] = {widget = widget, isShown = isShown}

                -- Check if this is a new widget or state changed
                local previousState = screenWidgets[widgetKey]
                if previousState == nil or previousState.isShown ~= isShown then
                    -- State changed - update viewport accordingly
                    if isShown then
                        ui.addViewportWidget(widget)
                    else
                        ui.removeViewportWidget(widget)
                    end
                end
            end

            -- Check for removed widgets and clean up
            for widgetKey, widgetData in pairs(screenWidgets) do
                if currentWidgets[widgetKey] == nil then
                    -- Widget was removed - remove from viewport if it was shown
                    if widgetData.isShown then
                        ui.removeViewportWidget(widgetData.widget)
                    end
                end
            end
		end)

        -- Update the tracked widgets
        screenWidgets = currentWidgets
    end
end)

local function getBoundsChildrenFromSkeletalMesh(parent)
    local result = {}
	if uevrUtils.validate_object(parent) ~= nil then
		local children = parent.AttachChildren
		if children ~= nil then
			for i, child in ipairs(children) do
				if child:is_a(uevrUtils.get_class("Class /Script/Alabama.BoundsComponent")) then
					table.insert(result, child)
				end
			end
		end
	end
	return result
end

setInterval(200, function()
    --set 2d mode during level changes so the ui has a nice black background
    local currentMatchState = uevrUtils.getMatchState()
    if currentMatchState ~= status["matchState"] then
        status["matchState"] = currentMatchState
        uevrUtils.set_2D_mode(currentMatchState ~= "InProgress")
    end

    if uevrUtils.getValid(pawn) ~= nil then
         if status["isClimbingLadder"] ~= pawn.bUseClimbingAnimations then
            status["isClimbingLadder"] = pawn.bUseClimbingAnimations
            onIsClimbingLadderChange(pawn.bUseClimbingAnimations == true)
        end
    end
end)

setInterval(1000, function()
    --hide secondary holstered weapons
    if uevrUtils.getValid(pawn) ~= nil then
        local children = getBoundsChildrenFromSkeletalMesh(uevrUtils.getValid(pawn, {"FirstPersonSkelMesh"}))
        if children then
            for i, child in ipairs(children) do
                --print("Bounds Component:", child.AttachSocketName)
                if string.find(child.AttachSocketName:to_string(), "holster") and child.AttachChildren ~= nil then
                    for j, grandChild in ipairs(child.AttachChildren) do
                        --print("  Child Component:", grandChild:get_full_name())
                        if (grandChild:is_a(uevrUtils.get_class("Class /Script/Engine.StaticMeshComponent")) or grandChild:is_a(uevrUtils.get_class("Class /Script/Engine.SkeletalMeshComponent"))) and not string.find(grandChild:get_full_name(), "UtilityRigMesh") then
                            --print("     Its hidden")
                            grandChild:SetHiddenInGame(true, true)
                            grandChild:SetVisibility(false, true)
                        end
                    end
                end
            end
        end
    end

end)

--Weapons holstered on the third-person body (pawn.Mesh): the game shows the inactive loadout's weapons sheathed on
--the body (hips, waist, back; MCP 2026-10-29: Sword_C on l_hips_holster_Sword1HSocket, Grimoire on
--lb_waist_att_GrimoireSocket, the whole copy visible including its UtilityRigMesh, so set by the game). In flat
--first person that body is never in view; in VR its holsters float in front of the player, and a loadout change
--shows them again. Hidden in first person (SetHiddenInGame, so the game's own SetVisibility changes still apply
--once restored), shown again for Full Body mode and cutscenes. Hand sockets (r_weapon_NSKSocket, l_Shield_Socket)
--are left alone so "Detach to Pawn" montages keep their weapon.
local MESH_CLASSES = { "Class /Script/Engine.StaticMeshComponent", "Class /Script/Engine.SkeletalMeshComponent" }
local hiddenBodyHolsterItems = {} --address -> component
local function isBodyHolsterSocket(socketName)
    local name = string.lower(socketName)
    return string.find(name, "holster", 1, true) ~= nil or string.find(name, "_att_", 1, true) ~= nil
end
local function isMeshComponent(component)
    for _, className in ipairs(MESH_CLASSES) do
        if component:is_a(uevrUtils.get_class(className)) then return true end
    end
    return false
end
setInterval(250, function()
    local hide = uevrUtils.getValid(pawn) ~= nil and not isFullBodyMode() and not uevrUtils.isInCutscene()
    if not hide then
        for _, component in pairs(hiddenBodyHolsterItems) do
            if uevrUtils.getValid(component) ~= nil then component:SetHiddenInGame(false, true) end
        end
        hiddenBodyHolsterItems = {}
        return
    end
    for _, bounds in ipairs(getBoundsChildrenFromSkeletalMesh(uevrUtils.getValid(pawn, {"Mesh"}))) do
        if bounds.AttachChildren ~= nil and isBodyHolsterSocket(bounds.AttachSocketName:to_string()) then
            for _, item in ipairs(bounds.AttachChildren) do
                if isMeshComponent(item) and item.bHiddenInGame ~= true then
                    item:SetHiddenInGame(true, true)
                    hiddenBodyHolsterItems[item:get_address()] = item
                end
            end
        end
    end
end)
uevrUtils.registerPreLevelChangeCallback(function(level)
    hiddenBodyHolsterItems = {} --old-world components
end)
