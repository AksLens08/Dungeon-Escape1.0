# Dungeon Escape 1.0

Dungeon Escape is a top-down dungeon crawler built with **LÖVE (Love2D)** and **Lua**.

## Overview
- Explore a dungeon generated from an image-based map.
- Collect coins, avoid Wizards, and survive the KM boss.
- Uses image-based collision, dynamic lighting, and simple enemy AI.

## Controls
| Action | Input |
| :--- | :--- |
| Movement | `W`, `A`, `S`, `D` or Arrow Keys |
| Attack | `Left Mouse Button` |
| Defend | `Right Mouse Button` |
| Pause | `P` |
| Quit | `Escape` |

## Run the Game
1. Install **LÖVE**.
2. Open the project folder in a terminal.
3. Run:
```bash
love .
```

## Notes
- `graphics/dungeon.png` defines walkable and blocked areas.
- `Dungeon` parses the image to build collision data.
- `Wizard` enemies use line-of-sight checks.
- `KM` is a boss enemy with separate attack behavior.

## Project Info
- Framework: LÖVE 11.x
- Language: Lua
- Core systems: dungeon parsing, collision, rendering, enemy AI.
