# Tetris PowerShell – Implementation Plan

## Goal
A fully playable Tetris clone in a single `Tetris.ps1` file, using Windows Forms + GDI+ for rendering. Style and conventions mirror `../samegamepowershell/SameGame.ps1`.

---

## Window Layout

```
+----------------------------------------------------------+
|  [hint text]            [Pause P]  [Settings S]  [New N] |  <- TOP_HEIGHT = 54 px
+----------------------+--+-----------------------------+---+
|                      |  |  NEXT                       |
|   GAME BOARD         |  |  +---------------------+   |
|   (COLS × ROWS)      |  |  |   preview (4×4 box) |   |
|   default 10 × 20    |  |  +---------------------+   |
|                      |  |                             |
|                      |  |  SCORE   99999              |
|                      |  |  LEVEL   10                 |
|                      |  |  LINES   999                |
+----------------------+  +-----------------------------+
      board area       gap        side panel
```

- **Top bar** (54 px): hint label (left) + 3 flat buttons (Pause, Settings, New Game) anchored to right.
- **Game panel**: double-buffered `TetrisPanel : Panel`. Contains both board area and side panel, painted together in `PaintBoard`.
- **Board area**: `COLS*(CELL+GAP)-GAP` wide, `ROWS*(CELL+GAP)-GAP` tall.
- **Side panel**: `max(4*(CELL+GAP)-GAP, 120)+20` px wide. Drawn at `x = boardWidth + SIDE_PAD`.

---

## CELL Size Auto-Calculation

```
usableH = 860 - TOP_HEIGHT
fromH   = floor((usableH + GAP) / ROWS) - GAP
CELL    = clamp(fromH, 18, 40)
```

Default ROWS=20 → CELL=37 px.

---

## Piece Definitions

Seven standard tetrominoes, stored in `$script:PIECE_DATA` as a nested array:

```
$script:PIECE_DATA[$type][$rot]  →  [int[]] of 8 values: r0,c0,r1,c1,r2,c2,r3,c3
```

All offsets are relative to the **piece origin** (top-left of a 4×4 bounding box for I; 3×3 for others).

| Index | Name | Color       |
|-------|------|-------------|
| 0     | I    | Cyan        |
| 1     | O    | Yellow      |
| 2     | T    | Purple      |
| 3     | S    | Green       |
| 4     | Z    | Red         |
| 5     | J    | Blue        |
| 6     | L    | Orange      |

Rotations 0–3 go **clockwise**. Wall-kick offsets tried on rotation failure: `[-1, +1, -2, +2]` columns.

---

## Tile Rendering (matches SameGame)

Each locked or active cell is drawn with:
1. **Drop shadow** (offset +3,+3, semi-transparent black)
2. **Hatch-brush face** (one `HatchStyle` per piece type; light/dark tones ±22/±28 from base colour)
3. **Top-left shine triangle** (75-alpha white)
4. **Bottom-right shadow triangle** (55-alpha black)
5. **Border rectangle** (90-alpha darkened colour, 1 px)

Ghost piece: outline-only rectangle (80-alpha coloured pen, 2 px).

---

## Game State Variables

| Variable | Type | Description |
|---|---|---|
| `$script:board` | `int[,]` | ROWS×COLS; -1=empty, 0-6=piece type |
| `$script:score` | int | cumulative score |
| `$script:level` | int | current level (starts at START_LEVEL) |
| `$script:lines` | int | total lines cleared |
| `$script:curType` | int | active piece type (0-6) |
| `$script:curRot` | int | active rotation (0-3) |
| `$script:curRow` | int | piece origin row |
| `$script:curCol` | int | piece origin col |
| `$script:nextType` | int | next piece type |
| `$script:gameOver` | bool | |
| `$script:paused` | bool | |
| `$script:gameTimer` | Timer | WinForms timer driving gravity |

---

## Key Functions

| Function | Signature | Description |
|---|---|---|
| `CalcCellSize` | `→ void` | Sets `$script:CELL` from ROWS |
| `GetCells` | `(type,rot,oRow,oCol) → [int[]]` | 8 absolute board coords |
| `IsValid` | `([int[]]cells) → bool` | bounds + occupancy check |
| `SpawnPiece` | `→ void` | nextType→curType, pick new nextType |
| `LockPiece` | `→ void` | stamp curType onto board |
| `GetGhostRow` | `→ int` | lowest valid row for current piece |
| `ClearLines` | `→ int` | removes full rows, returns count |
| `AddScore` | `(lines,softRows,hardRows) → void` | score + level-up + timer adjust |
| `TryMove` | `(dRow,dCol) → bool` | move piece if valid |
| `TryRotate` | `(dir) → bool` | rotate ±1 with wall-kick |
| `DoHardDrop` | `→ int` | drop to bottom, return rows dropped |

---

## Controls

| Key | Action |
|---|---|
| ← → | Move left / right |
| ↑ | Rotate clockwise |
| Z | Rotate counter-clockwise |
| ↓ | Soft drop (+1 pt/row) |
| Space | Hard drop (+2 pts/row) |
| P | Pause / Resume |
| N | New game |
| S | Settings |

---

## Settings Dialog

- **Board Size**: Columns (6–16), Rows (12–26) with NumericUpDown controls. Default 10×20.
- **Starting Level**: 1–10. Affects initial gravity speed and scoring multiplier.
- Buttons: **Apply & New Game** (OK) / **Cancel** (resume current game if not over).

---

## Gravity Speed (ms per tick)

```
Level:  1    2    3    4    5    6    7    8    9   10+
Speed: 800  720  630  550  470  380  300  220  130  100   80
```

---

## Scoring

```
Lines cleared at once:   0     1     2     3     4
Points (× level):        0   100   300   500   800
Soft drop per row:   +1
Hard drop per row:   +2
```

Level-up: every 10 cumulative lines cleared, starting from `START_LEVEL`.

---

## Build Steps

1. **[DONE] AGENTS.md** – instructions for agents working in this repo.
2. **[DONE] PLAN.md** – this document.
3. **Tetris.ps1 Part A** – `#Requires`, `Add-Type`, constants, `PIECE_DATA`, settings, game state, all logic helper functions, `DrawTile`, `PaintBoard`, `PaintSide`, `MakeIcon`, `ResizeUI`, then `if ($script:TetrisTestMode) { return }`.
4. **Tetris.ps1 Part B** – `TetrisPanel` type, form/controls construction, `$script:gameTimer`, event handlers (`StartNewGame`, `ShowSettings`, timer tick, `KeyDown`, button clicks), `Application::Run`.
5. **Tetris.Tests.ps1** – self-contained test runner covering all logic functions.
6. **Run tests** – all must pass; fix any failures.
