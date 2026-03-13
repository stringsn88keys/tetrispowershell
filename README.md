# Tetris — PowerShell Edition

Classic Tetris clone built with PowerShell, Windows Forms, and GDI+.

![Gameplay](screenshots/gameplay.png)

---

## Requirements

- Windows
- PowerShell 5.1 or later

## Running

```powershell
powershell -ExecutionPolicy Bypass -File Tetris.ps1
```

## Controls

| Key | Action |
|-----|--------|
| Left / Right | Move piece horizontally |
| Up | Rotate clockwise |
| Z | Rotate counter-clockwise |
| Down | Soft drop (+1 pt per row) |
| Space | Hard drop (+2 pts per row) |
| P | Pause / Resume |
| N | New game |
| S | Settings |

![Paused](screenshots/paused.png)

## Scoring

### Line clears (× level)

| Clear | Points |
|-------|--------|
| Single | 100 |
| Double | 300 |
| Triple | 500 |
| Tetris | 800 |

### T-Spins (× level)

| Clear | Full T-Spin | Mini T-Spin |
|-------|-------------|-------------|
| 0 lines | 400 | 100 |
| 1 line | 800 | 200 |
| 2 lines | 1200 | 400 |
| 3 lines | 1600 | — |

### Bonuses

- **Soft drop:** +1 pt per row
- **Hard drop:** +2 pts per row
- **Back-to-Back:** ×1.5 on consecutive difficult clears (Tetris or T-Spin line clear)
- **Combo:** +50 × combo count × level for each consecutive line clear (starts on 2nd clear)
- **No Ghost piece:** +50% to line clear score
- **Hide Next piece:** +25% to line clear score

A new level is reached every 10 lines. Speed increases with each level up to level 11.

## Settings

Press **S** or click the Settings button to adjust board width (6–16 columns), board height (10–30 rows), and starting level (1–11). Changes take effect on the next new game.

![Settings](screenshots/settings.png)

## Running Tests

```powershell
powershell -ExecutionPolicy Bypass -File Tetris.Tests.ps1
```
