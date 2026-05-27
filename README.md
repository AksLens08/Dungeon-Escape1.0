# Dungeon Escape 1.0

Dungeon Escape is a professional-grade top-down dungeon crawler developed using the **LÖVE (Love2D)** framework and **Lua**. The project features unique image-based level generation, advanced collision detection, and dynamic lighting.

## 🎮 Gameplay
You play as a Knight trapped within a dark, procedurally-populated dungeon. Your objective is to navigate the rocky corridors, collect gold coins to increase your score, and survive encounters with hostile Wizards and the formidable KM Bosses. 

Survival depends on balancing your **HP** and **Armor**. While armor regenerates over time, direct hits to your health are permanent until the game ends.

### Controls
| Action | Input |
| :--- | :--- |
| **Movement** | `W`, `A`, `S`, `D` or **Arrow Keys** |
| **Attack** | `Left Mouse Button` |
| **Defend (Block)** | `Right Mouse Button` |
| **Pause** | `P` |
| **Quit** | `Escape` |

## ⚙️ Mechanics

### 1. Image-Based Collision & Navigation
Instead of traditional tilemaps, `dungeon.lua` parses a PNG image (`graphics/dungeon.png`). 
- **White Pixels:** Walkable floor.
- **Black/Transparent Pixels:** Solid walls.
The system uses an **8-point sampling method** with insets to ensure the Knight doesn't get stuck on corners while allowing for smooth sliding along walls.

### 2. Combat System
- **Knight:** Features a state machine for `idle`, `walk`, `attack`, `hurt`, and `defend`. Blocking with the Right Mouse Button negates damage.
- **Wizards:** Ranged-style AI that wanders until the player enters their vision range (checked via raycasting).
- **KM Bosses:** High-speed enemies that trigger a "Jumpscare" state if they catch the player.

### 3. Atmosphere & Lighting
A custom **GLSL Radial Shader** simulates torchlight. The light position is dynamically calculated based on the Knight's current animation frame to ensure the "torch" remains centered on the sprite.

### 4. Audio Engine
Spatial-trigger audio for coin collection and state-dependent sounds (footsteps, shield hits, and hurt grunts) provide immersive feedback.

## 🗺 Development Milestones (The Quests)

### Quest 1: The Hero and the Maze
**Objective:** Create a controllable Knight and a dungeon layout that understands boundaries.
*   **Outcome:** Implemented the `Knight` class and `Dungeon` image-scanning collision.
*   **Feedback:** Collision was originally too blocky. **Fix:** Increased grid resolution by 4x.

### Quest 2: The Haunting
**Objective:** Populate the dungeon with enemies that react to the player.
*   **Outcome:** Added the `Enemy` class (Wizards) with a Line-of-Sight (LoS) algorithm.
*   **Feedback:** Enemies saw through walls. **Fix:** Implemented raycasting in `dungeon:hasLineOfSight`.

### Quest 3: The Glimmer
**Objective:** Add rewards for the player to collect.
*   **Outcome:** Created a managed `Coin` system with animated sprites.
*   **Feedback:** Hard to pick up. **Fix:** Expanded the collection hitbox beyond the visual sprite size.

### Quest 4: The Atmosphere
**Objective:** Make the dungeon feel dark and dangerous.
*   **Outcome:** Added GLSL shaders and spatial audio.
*   **Feedback:** Light was too restrictive. **Fix:** Balanced shader radius and added "ambient" darkness level.

### Quest 5: The Boss Encounter
**Objective:** Introduce high-stakes enemies and a game-over state.
*   **Outcome:** Added `KM` boss class and death states.
*   **Feedback:** Game ended too abruptly. **Fix:** Added a `deadAnimationComplete` check to allow animations to finish before the Game Over screen.

### Quest 6: The Clang of Steel
**Objective:** Implement reactive audio for combat states.
*   **Outcome:** Integrated `shield.mp3` for blocking and `taking_damage.mp3` for health/armor hits.
*   **Feedback:** Initially, shield sounds overlapped. **Fix:** Refined the audio manager to handle rapid re-triggering of combat samples.

## 👥 Developer Information
- **Lead Developer:** [Your Name/Handle]
- **Tools:** LÖVE 11.4+, Lua 5.1, Aseprite (Sprites), GLSL.
- **Objective:** Learning professional software architecture and OOP in game development.

---
*For future developers: Please refer to `ERRORS.md` for a complete log of technical hurdles and their respective solutions.*