# Avowed – UEVR VR Profile

A full motion-controller VR conversion of Avowed for UEVR. It has visible hands or full IK arms, weapons and shields held in your hands, and two melee styles: swing to attack, or physical melee where your weapon has to actually hit. It also adds shield blocking by raising your shield, a shoulder gesture for the inventory, and roomscale movement.

This profile is built on **jbusfield's original Avowed UEVR mod**, [jbusfield/AV_UEVR](https://github.com/jbusfield/AV_UEVR), and his uevrlib framework. Special thanks to praydog, jbusfield, markmon and joeyhodge!

## IMPORTANT!

- My custom UEVR build is required. It is attached to the [releases](https://github.com/letmein-vr/AVOWED_UEVR/releases) of this repo as `UEVR.zip`, next to the profile (`Avowed-Win64-Shipping.zip`). It includes the fixes needed for the latest Avowed patch.
- The profile ships with its plugins (`plugins/`). Keep `luakey.dll`: the inventory gesture uses it.

## Features

### Hands and arms

- **Two hand modes.** Pick **Hands** (VR hands made from your character's own gloves and sleeves) or **IK Arms** (full arms from your shoulders to the controllers, elbows solved in between). Switch live under **Options → Hands Mode** in the Avowed Config panel.
- **Your outfit, your hands.** The hands and arms are copies of what your character is wearing. Changing gloves or chest armour rebuilds them automatically.
- **Hand poses.** Fingers follow your trigger and grip, with grip poses for each weapon type.
- **Weapons locked to your hands.** In both modes, weapons and shields sit firmly in the hand. With IK arms they ride the IK hand with no lag.
- **Hidden when they should be.** Hands and arms hide while swimming, climbing ladders and during scripted animations.

### Weapons and combat

- **Weapons in hand.** Swords, spears, daggers, maces, wands, pistols, grimoires and shields sit in your hands with tuned offsets for each weapon. Bows are held in the left hand. Spell and grimoire effects come from the casting hand.
- **Aim follows your hand.** Attacks aim from the right hand by default, and from the left hand for bows and left-hand actions.
- **Weapon reticule.** A 3D crosshair, pure white, with a brightness slider (1–100).
- **Two melee modes**, switchable live under **Melee → Melee Mode**:
  - **Swing** – swing the controller to attack. A fast swing performs the game's strong (charged) attack. Left, right and downward swings attack; upward swings are ignored. Defaults to the classic fast attack speed (×10) with the attack lunge on.
  - **Physical** – the weapon has to touch the target. It hits enemies and breakables (crates, webs, walls), never your companions, and the hit is aimed at the spot your weapon touched, low crates on the floor included. Hand speed decides a normal or strong attack, and you get a haptic pulse on contact. Hit Forgiveness, Strike Delay, re-hit timing, aim hold time and scan range are all adjustable.
- **Per-mode attack speed and lunge.** Each melee mode keeps its own attack speed and its own "Stop Attack Lunges" setting (the dash toward the target on strong attacks).
- **Left-hand swings** attack in both modes.
- **Shield block.** Raise your shield close to your face to block. The shield shrinks while blocking so it doesn't fill your view (distance and size adjustable).
- **No floating holsters.** The game keeps your other loadout's weapons on the character's body; in VR they would float in front of you, so they are hidden in first person.

### Gestures

- **Inventory gesture.** Put your left hand on your left shoulder and squeeze the left grip to open the inventory, with a buzz to confirm. It's more reliable than long-pressing the menu button. Zone size and position are adjustable.

### Animations and scripted moments

- **No camera fights.** Doors, levers, containers, ladders and similar animations no longer fight the VR camera.
- **Per-animation rules.** For chosen animations, your weapons go back to the character and return to your hands afterwards, or either hand's weapon is hidden.

### Body, movement and comfort

- **Roomscale.** Your character follows you as you walk around your play space, and the body turns with your head.
- **Full Body Mode (experimental).** Uses the game's third-person body.
- **Ladders** handled in both first-person and full-body mode.
- **Head-locked game UI,** with a clean black background during loading screens.
- **Lumen toggle** for performance.

## Controls

Everything not listed uses the game's normal gamepad layout through UEVR's default controller bindings.

| Action | Input |
|---|---|
| Move | Left stick |
| Turn | Right stick |
| Attack (right hand) | Right trigger, or swing (Swing mode) / hit with the weapon (Physical mode) |
| Attack (left hand) | Left trigger, or swing the left hand |
| Strong attack | Hold the trigger, or a fast swing |
| Block | Raise the shield close to your face |
| Inventory | Left hand on left shoulder + left grip (or long-press the left menu button) |
| Pause menu | Left menu button |

## Installation

1. Download `UEVR.zip` and `Avowed-Win64-Shipping.zip` from the [releases](https://github.com/letmein-vr/AVOWED_UEVR/releases).
2. Extract `UEVR.zip` and use that UEVR to inject.
3. Import the profile in UEVR (or copy the files into `%APPDATA%\UnrealVRMod\Avowed-Win64-Shipping`).
4. Start the game and inject UEVR.

## Tuning

Everything you need day to day is in the **Avowed Config** panel in the UEVR overlay:

- **Input / UI / Reticule** – turning, UI placement, reticule size, distance and brightness.
- **Options** – Full Body Mode, Hands Mode (Hands / IK Arms), inventory gesture.
- **Shield Block** – gesture on/off, block distance, shield size while blocking.
- **Melee** – melee mode, strong-attack threshold, speed ceiling and hold time, attack speed and lunge per mode, and all physical melee settings.
- **Settings** – Lumen.

The developer panels (Attachments, Montages, IK rig) are hidden for release. To tune weapon offsets, animation rules or the IK rig, turn them back on:

- `attachments.init(false)` → `true` in `scripts/main.lua` (also shows the accessories panel)
- `montage.init(false)` → `true` in `scripts/main.lua`
- `SHOW_IK_DEV_PANEL = false` → `true` in `scripts/avowed/ik_arms.lua`

## Under the hood

Built on jbusfield's Avowed mod and his shared uevrlib Lua framework (`scripts/libs`), running on my UEVR backend. The Avowed-specific logic is in `scripts/main.lua` and in small modules under `scripts/avowed/`:

- `physical_melee.lua` – contact detection, and steering the game's own melee hit at the touched point.
- `ik_arms.lua` – the IK arms mode, and weapon anchors placed on the IK hands right after each solve.
- `no_lunge.lua` – removes the dash toward the target from attacks.
- `inventory_gesture.lua` – the shoulder gesture. It sends the I key through `luakey.dll`.

A few small Avowed patches sit in the libs on top of jbusfield's framework (named crosshair widget lookup, swipe strength ceiling, camera cleanup on level change, and the montage attachment rows).
