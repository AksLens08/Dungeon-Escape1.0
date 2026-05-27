# Dungeon Escape: Debugging & Error Log

This document tracks technical debt and solved issues to assist in future troubleshooting and onboarding.

| Error Encountered | Cause of the Error | Solution Used |
| :--- | :--- | :--- |
| **Syntax Error: `<eof>` expected** | Missing `end` keyword in `dungeon.lua` loops. | Audited nested loops in `Dungeon:init` and closed blocks properly. |
| **Invisible Walls / Collision Gaps** | Scanner checked single pixels, missing thin wall details in the PNG. | Implemented a grid-scanning offset to check a wider area per tile. |
| **"Sliding" through corners** | Hitboxes were identical to tile size, causing friction locks on corners. | Reduced hitbox dimensions and added a `1.0px` inset for 8-point sampling. |
| **Shader Offset/Lag** | Torchlight stayed at world coordinates, ignoring camera translation. | Converted player world coordinates to screen coordinates before sending to GLSL uniform. |
| **Stuck in "Hurt" state** | Invulnerability timer was set but never decremented in the update loop. | Added `self.invuln = self.invuln - dt` to the Knight's update function. |
| **KM Texture Load Failure** | Incorrect file pathing in `main.lua` for the KM boss sprite. | Patched `gTextures["KM"]` to look in `enemy/KM.png` and added `safelyLoadImage` wrapper. |
| **Diagonal Speed Boost** | Unnormalized input vectors allowed faster movement when moving diagonally. | Multiplied velocity by `0.7071` (1/sqrt(2)) when both X and Y inputs are active. |
| **Knight Health Overflow** | Armor depletion logic didn't account for leftover damage. | Rewrote `takeDamage` to subtract negative armor remainders from HP. |
| **Nil Method 'draw'** | Mixed use of `:draw()` and `:render()` across different classes. | Unified all rendering methods to `:render()` and fixed the `Coin.drawAll` call. |
| **Nil Method 'render' for Enemy** | `Enemy` class in `enemy.lua` still used `:draw()` instead of `:render()`. | Renamed `Enemy:draw()` to `Enemy:render()` in `enemy.lua`. Added defensive check in `main.lua` rendering loop. |
| **Persistent 'render' nil error** | Method call failed on line 241 despite previous fix. | Applied `type(obj.render) == 'function'` guards to Dungeon and Player objects in `main.lua`. |
| **Map Not Spawning (Black Screen)** | Strict collision scanner marked every tile as a wall, spawning player at (0,0) in the void. | Changed scanner to check tile centers only and added a hard fallback spawn at map center. |
| **Knight Spawning in Walls** | Spawner didn't account for Knight's internal centering offset. | Refined `getRandomSpawnPoint` to shuffle candidates and correctly center the hitbox on floor tiles. |
| **Wizard Static Animation** | Wizard class only used a walk strip and had no death state. | Reworked `Enemy` to use the `Class` system and state-based textures (`wizard_idle`, `wizard_death`, etc.). |
| **Shield Sound Silence** | Redundant `isPlaying` checks in `knight.lua` prevented sound from restarting. | Removed checks to allow the audio manager to restart the sample on every impact. |
| **KM Desynced Damage** | KM Boss dealt damage every frame in range, making hits feel "invisible." | Synchronized KM damage to only trigger on frame 2 of the "attack" state using a `hasHit` flag. |
| **Wizard Invisible/Broken Render** | `Enemy:render` was referencing old `spriteSheet` variables that were nil. | Refactored `Enemy:render` to use the `texture` and `quad` system. |
| **Attempt to call method 'heal'** | `Coin.updateAll` tried to call `player:heal()`, which was undefined. | Added the `heal(amount)` method to the `Knight` class. |
| **Wizards Not Doing Damage** | The hit frame for Wizards was set to 4, but the provided attack sprite sheet only has 4 frames (0-3). | Changed the Wizard's hit frame trigger to frame 2 to match the actual animation length. |