# Tasks & Warnings
## To-Do

## Warnings
- **Spawn Logic**: Check `dungeon.png` if spawn warnings appear.

## Resolved Errors
- **Hurt State Lock**: Fixed players getting stuck in "hurt" frames by resetting `attackTimer` upon taking damage.
- **Blurry Sprinting**: Resolved jittery diagonal movement by lowering the sprint multiplier (1.6x -> 1.3x) and syncing frame durations.
- **Missing Dependencies**: Fixed "Push is nil" crashes by adding `require("push")` to Archer and Spearman files.
- **Sprite Sheet Glitches**: Replaced hardcoded frame counts with dynamic detection (Width / 128) to stop sprite-bleeding.
- **Nil Variable Scopes**: Fixed `anim` and `canRunAttack` reference errors in the Spearman and Knight classes.
- **Knockback Scaling**: Refactored `Push.execute` to scale force based on damage amount rather than a flat value.
- **Entity Center Safety**: Added `if e.getCenter` checks in `main.lua` to prevent crashes during collision checks.
- **Slime Resource Loot**: Corrected the logic for players to properly regain mana or armor upon defeating slimes.
- **Speed & Acceleration Parity**: Balanced the Wizard's base speed and turning weight to feel identical to the Knight.
- **Attack Logic Sync**: Aligned Wizard's `flame` state duration with the actual 14-frame animation lifecycle.