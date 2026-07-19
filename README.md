# Hang Megiddo

**3D real-time strategy — Battle of Megiddo (c. 1457 BCE)**

Command **Thutmose III** after the Aruna pass against the Canaanite host before the walls of Megiddo.

Built with **Godot 4.7** (GDScript). Touch-first, Egyptian visual theme.

## Play in the browser

**Live game:** [https://drewarrowood.github.io/hangmegiddo/](https://drewarrowood.github.io/hangmegiddo/)

> First load downloads a large WASM pack (~38 MB). Tap/click the canvas once if the browser blocks input or audio.

### Controls

| Input | Action |
|-------|--------|
| Tap unit | Select (Egypt) / attack (enemy) |
| Tap ground | Move selected |
| **⚔ ATTACK-MOVE** | Advance and engage |
| Pinch / wheel | Zoom |
| Drag / WASD | Pan |
| Space | Pause |

### Victory

Shatter Canaanite strength, **hold Megiddo** long enough, or win the field at time limit.

## Desktop / source

```powershell
godot --path godot
# or
godot\launch.bat
```

Re-export web:

```powershell
godot --headless --path godot --export-release "Web" godot/build/web/index.html
# copy runtime files into docs/ (skip *.import)
```

## GitHub Pages

Served from the `docs/` folder on branch `main` (Godot Web export: `index.html`, `index.js`, `index.pck`, `index.wasm` + `.nojekyll`).

## Related

- [Hang Calhoun](https://github.com/drewarrowood/hangcalhoun) — 1830 operational wargame  
