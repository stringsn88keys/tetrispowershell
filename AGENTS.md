# Agent Instructions – Tetris PowerShell

## Test command
After every change to `Tetris.ps1`, run the test suite before considering the task done:

```
powershell -ExecutionPolicy Bypass -File Tetris.Tests.ps1
```

All tests must pass (exit code 0). If any test fails, fix the code (or the test if the expected behaviour genuinely changed) before finishing.

## Adding new functionality
When you add or change game logic, add corresponding tests to `Tetris.Tests.ps1`:

- **New helper function** → add a `Describe` block covering its normal cases and edge cases.
- **Bug fix** → add a regression test that would have caught the bug (name it clearly, e.g. `"[regression] wall-kick not applied on left wall"`).
- **Changed scoring rule** → update the Score Formula `Describe` block and the level-speed constant tests.
- **New piece or rotation** → add a `GetCells` test verifying every cell in every rotation.
- **New constant or grid dimension** → verify spawn column, ghost-row calculation, and boundary checks still pass.

## Project layout

| File | Purpose |
|---|---|
| `Tetris.ps1` | Game + UI. Setting `$script:TetrisTestMode = $true` before dot-sourcing skips all Windows Forms code so the logic functions load cleanly. |
| `Tetris.Tests.ps1` | Self-contained test runner (no Pester dependency). Dot-sources the game in test mode, then runs all assertions. |
| `PLAN.md` | Implementation context document. Describes architecture, design decisions, and step-by-step build plan. |

## Key architecture notes

- Board is `int[,]` (ROWS×COLS, default 20×10). Empty cell = `-1` (`$script:EMPTY`).
- Piece types: 0=I, 1=O, 2=T, 3=S, 4=Z, 5=J, 6=L.
- `$script:PIECE_DATA[$type][$rot]` is a **typed** `[int[]]` of 8 values: `r0,c0,r1,c1,r2,c2,r3,c3` — offsets relative to the piece origin.
- `script:GetCells $type $rot $oRow $oCol` returns a **flat `[int[]]` of 8 absolute board coords** (same layout). **Use `return ,$cells`** (comma prefix) so PowerShell does not unroll the array into the pipeline.
- `script:IsValid [int[]]$cells` checks 4 cells: columns must be in `[0, COLS)`, rows must be `< ROWS`; rows `< 0` (above the board) are allowed (spawning area) and skipped for board-occupancy checks.
- **Decode cell index with `[Math]::Floor($key / COLS)` not `[int]($key / COLS)`** — PowerShell's `[int]` cast rounds rather than truncates, which breaks columns ≥ 8. (Same bug as SameGame.)
- Functions that return arrays or `[int[]]` must use `return ,$value` to prevent PowerShell's pipeline from unrolling them into flat values.
- `if/else` used as an expression to assign a `System.Drawing.Color` or `float` can produce `Object[]` in PowerShell 5.1. Use explicit `$var = $null; if (...) { $var = A } else { $var = B }` instead.
- The game loop uses a `System.Windows.Forms.Timer` (`$script:gameTimer`). Its `Interval` is updated on level-up inside `AddScore`. In test mode `$script:gameTimer` is `$null`; guard with `if ($null -ne $script:gameTimer)`.
- `PIECE_DATA` inner arrays must be declared as `[int[]]@(...)` (typed) so PowerShell does not collapse them when nested inside plain `@()` arrays.

## Piece spawn convention
- Spawn origin: `curRow = 0`, `curCol = [Math]::Floor((COLS - 4) / 2)`.
- For a 10-wide board: `curCol = 3`. I piece (4-wide bounding box) lands on cols 3–6 at row 1; 3-wide pieces land on cols 3–5 at rows 0–1.
- Game over is detected immediately after `SpawnPiece`: if `IsValid(GetCells(curType, curRot, curRow, curCol))` returns `$false`, the board is topped-out.

## Scoring rules
| Event | Points |
|---|---|
| 1 line cleared | 100 × level |
| 2 lines cleared | 300 × level |
| 3 lines cleared | 500 × level |
| 4 lines cleared (Tetris) | 800 × level |
| Soft drop (per row) | 1 |
| Hard drop (per row) | 2 |

Level increases by 1 for every 10 cumulative lines cleared, starting from `START_LEVEL`.
