# Dungeon Escape 1.0

A small, fast-paced top-down dungeon crawler built with LÖVE (Love2D).

Jump into procedurally arranged rooms, face off against monsters, and survive long enough to escape the dungeon.

---

## Features

- Simple, responsive top-down controls and combat
- Melee attack and defend mechanics
- Room-based dungeon layout (design or procedurally arranged)
- Lightweight and easy to run with LÖVE

---

## Requirements

- LÖVE (Love2D) 11.3 or later (https://love2d.org)
- A desktop OS: Windows, macOS, or Linux

---

## Installation & Running

1. Install LÖVE from https://love2d.org.
2. Clone the repository or download the ZIP:

   git clone https://github.com/AksLens08/Dungeon-Escape1.0.git

3. Change into the project folder and run with LÖVE:

   love .

Alternatively you can package the project as a .love file and run that with LÖVE.

---

## Controls

- Move: W, A, S, D or Arrow keys
- Attack: Left Mouse Button (LMB)
- Defend / Block: Right Mouse Button (RMB)
- Pause / Menu: P

Tip: Use attack to deal damage and defend to reduce or avoid damage from enemies.

---

## Gameplay Overview

You control a dungeon explorer navigating rooms and corridors filled with enemies and hazards. Use movement and timed attacks to defeat foes, and defend to mitigate incoming damage. Progress through rooms to find an exit or reach objectives set by the level design.

Suggested goals:
- Clear all rooms
- Survive as long as possible (endless or time-based modes)
- Find keys or items to unlock new areas

---

## Project Structure (typical)

- main.lua — entry point
- conf.lua — LÖVE configuration
- src/ — game modules (entities, rooms, systems)
- assets/ — images, sounds, and other resources

(Adjust according to the repository layout if your files are organized differently.)

---

## Contributing

Contributions are welcome. If you'd like to:

1. Fork the repository
2. Create a branch for your feature or bugfix
3. Make changes and test locally with LÖVE
4. Open a pull request with a clear description of changes

Please include brief notes about any new assets or third-party resources you add.

---

## Tips for Development

- Keep assets in the `assets/` folder and reference them with relative paths.
- Use small sprites and tile-based rooms for faster iteration.
- Log or print helpful debug information during development and remove or gate it behind a debug flag for release builds.

---

## License

This project does not include a license file. If you want others to reuse or contribute, consider adding a license (for example, MIT License).

---

## Contact

If you have questions or suggestions, open an issue or pull request on GitHub:
https://github.com/AksLens08/Dungeon-Escape1.0
