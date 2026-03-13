#Requires -Version 5.1
<#
.SYNOPSIS
    Tetris - PowerShell Edition

.DESCRIPTION
    Classic Tetris clone with 7 tetrominoes, ghost piece, line clearing,
    levels, and score. Rendered with Windows Forms + GDI+.

    Controls:
      Left / Right    Move piece horizontally
      Up              Rotate clockwise
      Z               Rotate counter-clockwise
      Down            Soft drop  (+1 pt per row)
      Space           Hard drop  (+2 pts per row)
      P               Pause / Resume
      N               New game
      S               Settings

.NOTES
    Run with:
        powershell -ExecutionPolicy Bypass -File Tetris.ps1
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ------------------------------------------------------------------
#  CONSTANTS
# ------------------------------------------------------------------
$script:GAP        = 3     # gap between cells (px)
$script:EMPTY      = -1    # sentinel for empty cell
$script:TOP_HEIGHT = 54    # top-bar height (px)
$script:SIDE_PAD   = 14    # gap between board and side panel (px)

# ------------------------------------------------------------------
#  PIECE COLORS  (I O T S Z J L — indices 0-6)
# ------------------------------------------------------------------
$script:PIECE_COLORS = @(
    [System.Drawing.Color]::FromArgb( 28, 200, 205),   # 0  I  Cyan
    [System.Drawing.Color]::FromArgb(230, 188,  28),   # 1  O  Yellow
    [System.Drawing.Color]::FromArgb(160,  48, 210),   # 2  T  Purple
    [System.Drawing.Color]::FromArgb( 48, 185,  68),   # 3  S  Green
    [System.Drawing.Color]::FromArgb(210,  48,  48),   # 4  Z  Red
    [System.Drawing.Color]::FromArgb( 48, 108, 220),   # 5  J  Blue
    [System.Drawing.Color]::FromArgb(235, 120,  30)    # 6  L  Orange
)

$script:PIECE_NAMES = @('I','O','T','S','Z','J','L')

# One distinct hatch pattern per piece type
$script:PIECE_HATCHES = @(
    [System.Drawing.Drawing2D.HatchStyle]::WideDownwardDiagonal,  # 0  I
    [System.Drawing.Drawing2D.HatchStyle]::Cross,                  # 1  O
    [System.Drawing.Drawing2D.HatchStyle]::DiagonalCross,          # 2  T
    [System.Drawing.Drawing2D.HatchStyle]::LargeCheckerBoard,      # 3  S
    [System.Drawing.Drawing2D.HatchStyle]::WideUpwardDiagonal,    # 4  Z
    [System.Drawing.Drawing2D.HatchStyle]::DarkDownwardDiagonal,  # 5  J
    [System.Drawing.Drawing2D.HatchStyle]::DarkUpwardDiagonal     # 6  L
)

# ------------------------------------------------------------------
#  PIECE DATA
#  7 pieces x 4 rotations x 8 ints: r0,c0,r1,c1,r2,c2,r3,c3
#  All offsets relative to piece origin (top-left of bounding box).
#  I uses a 4x4 box; O, T, S, Z, J, L use a 3x3 box.
# ------------------------------------------------------------------
$script:PIECE_DATA = @(
    # 0: I
    @(
        [int[]]@(1,0, 1,1, 1,2, 1,3),  # rot 0:  . . . . / I I I I / . . . . / . . . .
        [int[]]@(0,2, 1,2, 2,2, 3,2),  # rot 1:  . . I . / . . I . / . . I . / . . I .
        [int[]]@(2,0, 2,1, 2,2, 2,3),  # rot 2:  . . . . / . . . . / I I I I / . . . .
        [int[]]@(0,1, 1,1, 2,1, 3,1)   # rot 3:  . I . . / . I . . / . I . . / . I . .
    ),
    # 1: O
    @(
        [int[]]@(0,1, 0,2, 1,1, 1,2),  # all rotations identical
        [int[]]@(0,1, 0,2, 1,1, 1,2),
        [int[]]@(0,1, 0,2, 1,1, 1,2),
        [int[]]@(0,1, 0,2, 1,1, 1,2)
    ),
    # 2: T
    @(
        [int[]]@(0,1, 1,0, 1,1, 1,2),  # rot 0:  . T . / T T T / . . .
        [int[]]@(0,1, 1,1, 1,2, 2,1),  # rot 1:  . T . / . T T / . T .
        [int[]]@(1,0, 1,1, 1,2, 2,1),  # rot 2:  . . . / T T T / . T .
        [int[]]@(0,1, 1,0, 1,1, 2,1)   # rot 3:  . T . / T T . / . T .
    ),
    # 3: S
    @(
        [int[]]@(0,1, 0,2, 1,0, 1,1),  # rot 0:  . S S / S S . / . . .
        [int[]]@(0,1, 1,1, 1,2, 2,2),  # rot 1:  . S . / . S S / . . S
        [int[]]@(1,1, 1,2, 2,0, 2,1),  # rot 2:  . . . / . S S / S S .
        [int[]]@(0,0, 1,0, 1,1, 2,1)   # rot 3:  S . . / S S . / . S .
    ),
    # 4: Z
    @(
        [int[]]@(0,0, 0,1, 1,1, 1,2),  # rot 0:  Z Z . / . Z Z / . . .
        [int[]]@(0,2, 1,1, 1,2, 2,1),  # rot 1:  . . Z / . Z Z / . Z .
        [int[]]@(1,0, 1,1, 2,1, 2,2),  # rot 2:  . . . / Z Z . / . Z Z
        [int[]]@(0,1, 1,0, 1,1, 2,0)   # rot 3:  . Z . / Z Z . / Z . .
    ),
    # 5: J
    @(
        [int[]]@(0,0, 1,0, 1,1, 1,2),  # rot 0:  J . . / J J J / . . .
        [int[]]@(0,1, 0,2, 1,1, 2,1),  # rot 1:  . J J / . J . / . J .
        [int[]]@(1,0, 1,1, 1,2, 2,2),  # rot 2:  . . . / J J J / . . J
        [int[]]@(0,1, 1,1, 2,0, 2,1)   # rot 3:  . J . / . J . / J J .
    ),
    # 6: L
    @(
        [int[]]@(0,2, 1,0, 1,1, 1,2),  # rot 0:  . . L / L L L / . . .
        [int[]]@(0,1, 1,1, 2,1, 2,2),  # rot 1:  . L . / . L . / . L L
        [int[]]@(1,0, 1,1, 1,2, 2,0),  # rot 2:  . . . / L L L / L . .
        [int[]]@(0,0, 0,1, 1,1, 2,1)   # rot 3:  L L . / . L . / . L .
    )
)

# Score table: LINE_SCORES[n] * level  (n = lines cleared at once, 0-4)
# T-Spin and Mini T-Spin scores are handled separately in AddScore.
$script:LINE_SCORES = @(0, 100, 300, 500, 800)

# Gravity interval (ms per tick) per level; index = level-1, clamped at 10
$script:LEVEL_SPEEDS = @(800, 720, 630, 550, 470, 380, 300, 220, 130, 100, 80)

# ------------------------------------------------------------------
#  SETTINGS  (mutable - changed via settings dialog)
# ------------------------------------------------------------------
$script:COLS        = 10
$script:ROWS        = 20
$script:START_LEVEL = 1
$script:CELL        = 37   # auto-computed by CalcCellSize
$script:NO_GHOST    = $false  # hide ghost piece (+50% line score bonus)
$script:HIDE_NEXT   = $false  # hide next-piece preview (+25% line score bonus)

# ------------------------------------------------------------------
#  GAME STATE
# ------------------------------------------------------------------
$script:board          = $null   # int[,] ROWS x COLS
$script:score          = 0
$script:level          = 1
$script:lines          = 0
$script:combo          = -1     # combo counter; -1 = inactive, 0 = first clear (no bonus)
$script:b2b            = $false # back-to-back difficult clear streak
$script:lastWasRotate  = $false # true if last successful action was a rotation (for T-Spin)
$script:curType        = 0      # current piece type 0-6
$script:curRot         = 0      # current rotation 0-3
$script:curRow         = 0      # origin row
$script:curCol         = 0      # origin col
$script:nextType       = 0      # next piece type
$script:gameOver       = $false
$script:paused         = $false
$script:gameTimer      = $null  # System.Windows.Forms.Timer (set in UI section)

# ------------------------------------------------------------------
#  HELPERS
# ------------------------------------------------------------------

# Auto-scale cell size so the board fits vertically (capped at 40px)
function script:CalcCellSize {
    $usableH = 860 - $script:TOP_HEIGHT
    $fromH   = [Math]::Floor(($usableH + $script:GAP) / $script:ROWS) - $script:GAP
    $script:CELL = [Math]::Max(18, [Math]::Min(40, $fromH))
}

# Returns a flat [int[]] of 8 absolute board coords: r0,c0,r1,c1,r2,c2,r3,c3
function script:GetCells([int]$type, [int]$rot, [int]$oRow, [int]$oCol) {
    $d = $script:PIECE_DATA[$type][$rot]
    [int[]]$cells = @(
        ($oRow + $d[0]), ($oCol + $d[1]),
        ($oRow + $d[2]), ($oCol + $d[3]),
        ($oRow + $d[4]), ($oCol + $d[5]),
        ($oRow + $d[6]), ($oCol + $d[7])
    )
    return ,$cells
}

# Returns $true if all 4 cells are within bounds and unoccupied.
# Cells with r < 0 (above the board) pass the occupancy check (spawn area).
function script:IsValid([int[]]$cells) {
    for ($i = 0; $i -lt 8; $i += 2) {
        $r = $cells[$i]
        $c = $cells[$i + 1]
        if ($c -lt 0 -or $c -ge $script:COLS) { return $false }
        if ($r -ge $script:ROWS)              { return $false }
        if ($r -ge 0 -and $script:board[$r, $c] -ne $script:EMPTY) { return $false }
    }
    return $true
}

# Advance nextType -> curType; pick a new nextType
function script:SpawnPiece {
    $script:curType       = $script:nextType
    $script:curRot        = 0
    $script:curRow        = 0
    $script:curCol        = [Math]::Floor(($script:COLS - 4) / 2)
    $script:nextType      = Get-Random -Minimum 0 -Maximum 7
    $script:lastWasRotate = $false
}

# Stamp the current piece colour onto the board
function script:LockPiece {
    $cells = script:GetCells $script:curType $script:curRot $script:curRow $script:curCol
    for ($i = 0; $i -lt 8; $i += 2) {
        $r = $cells[$i]; $c = $cells[$i + 1]
        if ($r -ge 0 -and $r -lt $script:ROWS -and $c -ge 0 -and $c -lt $script:COLS) {
            $script:board[$r, $c] = $script:curType
        }
    }
}

# Returns the lowest row the current piece can reach (ghost piece row)
function script:GetGhostRow {
    $gr = $script:curRow
    while ($true) {
        $next = script:GetCells $script:curType $script:curRot ($gr + 1) $script:curCol
        if (script:IsValid $next) { $gr++ } else { break }
    }
    return $gr
}

# Remove full rows, shift rows down, return number of lines cleared
function script:ClearLines {
    $cleared = 0
    $wr = $script:ROWS - 1
    for ($r = $script:ROWS - 1; $r -ge 0; $r--) {
        $full = $true
        for ($c = 0; $c -lt $script:COLS; $c++) {
            if ($script:board[$r, $c] -eq $script:EMPTY) { $full = $false; break }
        }
        if (-not $full) {
            if ($wr -ne $r) {
                for ($c = 0; $c -lt $script:COLS; $c++) {
                    $script:board[$wr, $c] = $script:board[$r, $c]
                }
            }
            $wr--
        } else {
            $cleared++
        }
    }
    # Fill vacated rows at top with EMPTY
    while ($wr -ge 0) {
        for ($c = 0; $c -lt $script:COLS; $c++) {
            $script:board[$wr, $c] = $script:EMPTY
        }
        $wr--
    }
    return $cleared
}

# Add points, track lines/combo/B2B, level up if needed, adjust timer interval.
# tSpinType: 'Full' | 'Mini' | 'None'  (from GetTSpinType before locking)
# Line scores are boosted +50% when NO_GHOST and +25% when HIDE_NEXT.
function script:AddScore([int]$linesCleared, [int]$softRows, [int]$hardRows, [string]$tSpinType = 'None') {
    # Determine base score and whether this qualifies as a difficult clear.
    $baseScore   = 0
    $isDifficult = $false
    if ($tSpinType -eq 'Full') {
        switch ($linesCleared) {
            0 { $baseScore = 400 }
            1 { $baseScore = 800;  $isDifficult = $true }
            2 { $baseScore = 1200; $isDifficult = $true }
            3 { $baseScore = 1600; $isDifficult = $true }
        }
    } elseif ($tSpinType -eq 'Mini') {
        switch ($linesCleared) {
            0 { $baseScore = 100 }
            1 { $baseScore = 200; $isDifficult = $true }
            2 { $baseScore = 400; $isDifficult = $true }
        }
    } else {
        $baseScore = $script:LINE_SCORES[$linesCleared]
        if ($linesCleared -eq 4) { $isDifficult = $true }
    }

    $lineScore = $baseScore * $script:level

    # Back-to-Back: consecutive difficult line clears get 1.5x multiplier.
    # B2B state only changes when lines are actually cleared.
    if ($linesCleared -gt 0) {
        if ($isDifficult) {
            if ($script:b2b) { $lineScore = [int]($lineScore * 1.5) }
            $script:b2b = $true
        } else {
            $script:b2b = $false
        }
    }

    # Combo: +50 * combo * level for each consecutive line clear (bonus starts on 2nd clear).
    if ($linesCleared -gt 0) {
        $script:combo++
        if ($script:combo -gt 0) { $lineScore += 50 * $script:combo * $script:level }
    } else {
        $script:combo = -1
    }

    if ($script:NO_GHOST)  { $lineScore = [int]($lineScore * 1.5) }
    if ($script:HIDE_NEXT) { $lineScore = [int]($lineScore * 1.25) }

    $script:score += $lineScore
    $script:score += $softRows
    $script:score += $hardRows * 2

    $script:lines += $linesCleared
    $newLevel = $script:START_LEVEL + [Math]::Floor($script:lines / 10)
    if ($newLevel -gt $script:level) {
        $script:level = $newLevel
        if ($null -ne $script:gameTimer) {
            $idx = [Math]::Min($script:level - 1, 10)
            $script:gameTimer.Interval = $script:LEVEL_SPEEDS[$idx]
        }
    }
}

# Move piece by (dRow, dCol); returns $true if the move succeeded
function script:TryMove([int]$dRow, [int]$dCol) {
    $cells = script:GetCells $script:curType $script:curRot ($script:curRow + $dRow) ($script:curCol + $dCol)
    if (script:IsValid $cells) {
        $script:curRow += $dRow
        $script:curCol += $dCol
        $script:lastWasRotate = $false
        return $true
    }
    return $false
}

# Rotate piece clockwise (dir=+1) or CCW (dir=-1) with simple wall-kick.
# Returns $true if rotation succeeded.
function script:TryRotate([int]$dir) {
    $newRot = ($script:curRot + $dir + 4) % 4
    $cells  = script:GetCells $script:curType $newRot $script:curRow $script:curCol
    if (script:IsValid $cells) {
        $script:curRot = $newRot
        $script:lastWasRotate = $true
        return $true
    }
    # Wall-kick: try column offsets -1, +1, -2, +2
    foreach ($dc in @(-1, 1, -2, 2)) {
        $cells = script:GetCells $script:curType $newRot $script:curRow ($script:curCol + $dc)
        if (script:IsValid $cells) {
            $script:curRot  = $newRot
            $script:curCol += $dc
            $script:lastWasRotate = $true
            return $true
        }
    }
    return $false
}

# Drop current piece to the lowest valid row; returns number of rows dropped.
# Does NOT lock the piece.
function script:DoHardDrop {
    $dropped = 0
    while (script:TryMove 1 0) { $dropped++ }
    return $dropped
}

# Returns $true if board position (r,c) is occupied (out-of-bounds counts as occupied).
function script:IsCornerOccupied([int]$r, [int]$c) {
    if ($r -lt 0 -or $r -ge $script:ROWS -or $c -lt 0 -or $c -ge $script:COLS) { return $true }
    return $script:board[$r, $c] -ne $script:EMPTY
}

# Returns 'Full', 'Mini', or 'None' for the current piece position.
# Only meaningful for T-piece (type 2) when lastWasRotate is $true.
function script:GetTSpinType {
    if ($script:curType -ne 2)          { return 'None' }
    if (-not $script:lastWasRotate)     { return 'None' }

    $r  = $script:curRow
    $c  = $script:curCol
    $tl = script:IsCornerOccupied $r       $c
    $tr = script:IsCornerOccupied $r       ($c + 2)
    $bl = script:IsCornerOccupied ($r + 2) $c
    $br = script:IsCornerOccupied ($r + 2) ($c + 2)
    $total = ([int]$tl + [int]$tr + [int]$bl + [int]$br)

    if ($total -ge 3) { return 'Full' }
    if ($total -lt 2) { return 'None' }
    # Exactly 2: Mini T-Spin only if both front corners are the occupied ones.
    # Front corners by rotation: 0=TL+TR, 1=TR+BR, 2=BL+BR, 3=TL+BL
    switch ($script:curRot) {
        0 { if ($tl -and $tr) { return 'Mini' } }
        1 { if ($tr -and $br) { return 'Mini' } }
        2 { if ($bl -and $br) { return 'Mini' } }
        3 { if ($tl -and $bl) { return 'Mini' } }
    }
    return 'None'
}

# ------------------------------------------------------------------
#  DRAWING HELPERS
# ------------------------------------------------------------------

# Draw one tile at pixel position (x, y).  isGhost = outline-only.
function script:DrawTile([System.Drawing.Graphics]$gfx, [int]$x, [int]$y, [int]$ci, [bool]$isGhost) {
    $cs   = $script:CELL
    $base = $script:PIECE_COLORS[$ci]

    if ($isGhost) {
        $penClr = [System.Drawing.Color]::FromArgb(80, $base.R, $base.G, $base.B)
        $pen    = [System.Drawing.Pen]::new($penClr, 2.0)
        $gfx.DrawRectangle($pen, $x, $y, $cs, $cs)
        $pen.Dispose()
        return
    }

    # Drop shadow
    $sh = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(70, 0, 0, 0))
    $gfx.FillRectangle($sh, ($x + 3), ($y + 3), $cs, $cs)
    $sh.Dispose()

    # Two-tone hatch face
    $clrDark  = [System.Drawing.Color]::FromArgb(
        [Math]::Max(0,   $base.R - 22),
        [Math]::Max(0,   $base.G - 22),
        [Math]::Max(0,   $base.B - 22))
    $clrLight = [System.Drawing.Color]::FromArgb(
        [Math]::Min(255, $base.R + 28),
        [Math]::Min(255, $base.G + 28),
        [Math]::Min(255, $base.B + 28))
    $hatch = [System.Drawing.Drawing2D.HatchBrush]::new(
        $script:PIECE_HATCHES[$ci], $clrLight, $clrDark)
    $gfx.FillRectangle($hatch, $x, $y, $cs, $cs)
    $hatch.Dispose()

    # Top-left specular triangle (shine)
    $shine = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(75, 255, 255, 255))
    $hiPts = [System.Drawing.PointF[]]@(
        [System.Drawing.PointF]::new($x,       $y),
        [System.Drawing.PointF]::new($x + $cs, $y),
        [System.Drawing.PointF]::new($x,       $y + $cs)
    )
    $gfx.FillPolygon($shine, $hiPts)
    $shine.Dispose()

    # Bottom-right shadow triangle
    $dk = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(55, 0, 0, 0))
    $dkPts = [System.Drawing.PointF[]]@(
        [System.Drawing.PointF]::new($x + $cs, $y),
        [System.Drawing.PointF]::new($x + $cs, $y + $cs),
        [System.Drawing.PointF]::new($x,       $y + $cs)
    )
    $gfx.FillPolygon($dk, $dkPts)
    $dk.Dispose()

    # Border
    $borderClr = [System.Drawing.Color]::FromArgb(90,
        [Math]::Max(0, $base.R - 55),
        [Math]::Max(0, $base.G - 55),
        [Math]::Max(0, $base.B - 55))
    $pen = [System.Drawing.Pen]::new($borderClr, 1.0)
    $gfx.DrawRectangle($pen, $x, $y, $cs, $cs)
    $pen.Dispose()
}

# ------------------------------------------------------------------
#  MAIN PAINT
# ------------------------------------------------------------------
function script:PaintBoard([System.Windows.Forms.PaintEventArgs]$e) {
    $gfx    = $e.Graphics
    $cs     = $script:CELL
    $gap    = $script:GAP
    $boardW = $script:COLS * ($cs + $gap) - $gap
    $boardH = $script:ROWS * ($cs + $gap) - $gap

    # Outer background
    $bg = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(24, 24, 36))
    $gfx.FillRectangle($bg, $e.ClipRectangle)
    $bg.Dispose()

    # Board well background
    $bbg = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(14, 14, 24))
    $gfx.FillRectangle($bbg, 0, 0, $boardW, $boardH)
    $bbg.Dispose()

    # Subtle grid lines
    $gridPen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(28, 255, 255, 255), 1.0)
    for ($r = 0; $r -le $script:ROWS; $r++) {
        $yy = $r * ($cs + $gap)
        $gfx.DrawLine($gridPen, 0, $yy, $boardW, $yy)
    }
    for ($cc = 0; $cc -le $script:COLS; $cc++) {
        $xx = $cc * ($cs + $gap)
        $gfx.DrawLine($gridPen, $xx, 0, $xx, $boardH)
    }
    $gridPen.Dispose()

    # Ghost piece (only when playing and NO_GHOST is off)
    if (-not $script:gameOver -and -not $script:paused -and -not $script:NO_GHOST) {
        $ghostRow = script:GetGhostRow
        if ($ghostRow -ne $script:curRow) {
            $gc = script:GetCells $script:curType $script:curRot $ghostRow $script:curCol
            for ($i = 0; $i -lt 8; $i += 2) {
                $r = $gc[$i]; $c = $gc[$i + 1]
                if ($r -ge 0 -and $r -lt $script:ROWS) {
                    script:DrawTile $gfx ($c * ($cs + $gap)) ($r * ($cs + $gap)) $script:curType $true
                }
            }
        }
    }

    # Locked pieces on board
    for ($r = 0; $r -lt $script:ROWS; $r++) {
        for ($c = 0; $c -lt $script:COLS; $c++) {
            $ci = $script:board[$r, $c]
            if ($ci -eq $script:EMPTY) { continue }
            script:DrawTile $gfx ($c * ($cs + $gap)) ($r * ($cs + $gap)) $ci $false
        }
    }

    # Current falling piece (only when playing)
    if (-not $script:gameOver -and -not $script:paused) {
        $cc2 = script:GetCells $script:curType $script:curRot $script:curRow $script:curCol
        for ($i = 0; $i -lt 8; $i += 2) {
            $r = $cc2[$i]; $c = $cc2[$i + 1]
            if ($r -ge 0 -and $r -lt $script:ROWS) {
                script:DrawTile $gfx ($c * ($cs + $gap)) ($r * ($cs + $gap)) $script:curType $false
            }
        }
    }

    # Side panel
    script:PaintSide $gfx ($boardW + $script:SIDE_PAD)

    # Pause overlay
    if ($script:paused -and -not $script:gameOver) {
        $ov = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(160, 8, 8, 18))
        $gfx.FillRectangle($ov, 0, 0, $boardW, $boardH)
        $ov.Dispose()
        $fnt = [System.Drawing.Font]::new("Segoe UI", 28, [System.Drawing.FontStyle]::Bold)
        $sf  = [System.Drawing.StringFormat]::new()
        $sf.Alignment     = [System.Drawing.StringAlignment]::Center
        $sf.LineAlignment = [System.Drawing.StringAlignment]::Center
        $br2 = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::White)
        $gfx.DrawString("PAUSED", $fnt, $br2,
            [System.Drawing.RectangleF]::new(0, 0, $boardW, $boardH), $sf)
        $fnt.Dispose(); $sf.Dispose(); $br2.Dispose()
    }

    # Game-over overlay
    if ($script:gameOver) {
        $ov = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(170, 8, 8, 18))
        $gfx.FillRectangle($ov, 0, 0, $boardW, $boardH)
        $ov.Dispose()
        $fnt = [System.Drawing.Font]::new("Segoe UI", 22, [System.Drawing.FontStyle]::Bold)
        $sf  = [System.Drawing.StringFormat]::new()
        $sf.Alignment     = [System.Drawing.StringAlignment]::Center
        $sf.LineAlignment = [System.Drawing.StringAlignment]::Center
        $br2 = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::White)
        $gfx.DrawString("GAME OVER`nScore: $($script:score)", $fnt, $br2,
            [System.Drawing.RectangleF]::new(0, 0, $boardW, $boardH), $sf)
        $fnt.Dispose(); $sf.Dispose(); $br2.Dispose()
    }
}

# Draw NEXT preview + score/level/lines into the side panel
function script:PaintSide([System.Drawing.Graphics]$gfx, [int]$sideX) {
    $cs  = $script:CELL
    $gap = $script:GAP

    $clrHead = [System.Drawing.Color]::FromArgb(140, 140, 210)
    $clrVal  = [System.Drawing.Color]::FromArgb(195, 195, 235)
    $fntLbl  = [System.Drawing.Font]::new("Segoe UI", 8,  [System.Drawing.FontStyle]::Bold)
    $fntVal  = [System.Drawing.Font]::new("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)

    # NEXT label
    $brH = [System.Drawing.SolidBrush]::new($clrHead)
    $nextLabel = if ($script:HIDE_NEXT) { "NEXT  [hidden +25%]" } else { "NEXT" }
    $gfx.DrawString($nextLabel, $fntLbl, $brH, [float]$sideX, 8.0)
    $brH.Dispose()

    # Preview box (4x4 cells)
    $prevSize = 4 * ($cs + $gap) - $gap
    $prevY    = 28
    $pbg = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(14, 14, 24))
    $gfx.FillRectangle($pbg, $sideX, $prevY, $prevSize, $prevSize)
    $pbg.Dispose()
    $pBdr = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(55, 255, 255, 255), 1.0)
    $gfx.DrawRectangle($pBdr, $sideX, $prevY, $prevSize, $prevSize)
    $pBdr.Dispose()

    if ($script:HIDE_NEXT) {
        # Show a "?" in the centre of the preview box
        $fntQ  = [System.Drawing.Font]::new("Segoe UI", 22, [System.Drawing.FontStyle]::Bold)
        $sfQ   = [System.Drawing.StringFormat]::new()
        $sfQ.Alignment     = [System.Drawing.StringAlignment]::Center
        $sfQ.LineAlignment = [System.Drawing.StringAlignment]::Center
        $brQ   = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(90, 90, 130))
        $gfx.DrawString("?", $fntQ, $brQ,
            [System.Drawing.RectangleF]::new($sideX, $prevY, $prevSize, $prevSize), $sfQ)
        $fntQ.Dispose(); $sfQ.Dispose(); $brQ.Dispose()
    } else {
        # Draw NEXT piece at rotation 0
        $nc = script:GetCells $script:nextType 0 0 0
        for ($i = 0; $i -lt 8; $i += 2) {
            $r = $nc[$i]; $c = $nc[$i + 1]
            script:DrawTile $gfx ($sideX + $c * ($cs + $gap)) ($prevY + $r * ($cs + $gap)) $script:nextType $false
        }
    }

    # Stats
    $sy  = $prevY + $prevSize + 18
    $brH = [System.Drawing.SolidBrush]::new($clrHead)
    $brV = [System.Drawing.SolidBrush]::new($clrVal)

    $gfx.DrawString("SCORE", $fntLbl, $brH, [float]$sideX, [float]$sy)
    $gfx.DrawString("$($script:score)", $fntVal, $brV, [float]$sideX, [float]($sy + 15))
    $gfx.DrawString("LEVEL", $fntLbl, $brH, [float]$sideX, [float]($sy + 50))
    $gfx.DrawString("$($script:level)", $fntVal, $brV, [float]$sideX, [float]($sy + 65))
    $gfx.DrawString("LINES", $fntLbl, $brH, [float]$sideX, [float]($sy + 100))
    $gfx.DrawString("$($script:lines)", $fntVal, $brV, [float]$sideX, [float]($sy + 115))

    $brH.Dispose(); $brV.Dispose()
    $fntLbl.Dispose(); $fntVal.Dispose()
}

# Build a 32x32 icon: T-tetromino in purple
function script:MakeIcon {
    $sz  = 32
    $bmp = [System.Drawing.Bitmap]::new($sz, $sz,
               [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g   = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None
    $g.Clear([System.Drawing.Color]::FromArgb(24, 24, 36))

    $tClr  = [System.Drawing.Color]::FromArgb(160, 48, 210)  # T-purple
    $ts    = 9   # tile size in icon
    # T-piece cells: top-center + bottom row of 3
    $tCells = @( @(0,1), @(1,0), @(1,1), @(1,2) )
    $startX = 2; $startY = 7

    foreach ($cell in $tCells) {
        $cx = $startX + $cell[1] * ($ts + 1)
        $cy = $startY + $cell[0] * ($ts + 1)
        $br = [System.Drawing.SolidBrush]::new($tClr)
        $g.FillRectangle($br, $cx, $cy, $ts, $ts)
        $br.Dispose()
        $sh = [System.Drawing.SolidBrush]::new(
                  [System.Drawing.Color]::FromArgb(80, 255, 255, 255))
        $pts = [System.Drawing.Point[]]@(
            [System.Drawing.Point]::new($cx,       $cy),
            [System.Drawing.Point]::new($cx + $ts, $cy),
            [System.Drawing.Point]::new($cx,       $cy + $ts))
        $g.FillPolygon($sh, $pts)
        $sh.Dispose()
    }

    $g.Dispose()
    $icon = [System.Drawing.Icon]::FromHandle($bmp.GetHicon())
    $bmp.Dispose()
    return $icon
}

# Resize window and reposition controls to match current settings
function script:ResizeUI($frm, $tb, $gp, $bNew, $bSet, $bPause, $hintLbl) {
    $cs      = $script:CELL
    $gap     = $script:GAP
    $boardW  = $script:COLS * ($cs + $gap) - $gap
    $boardH  = $script:ROWS * ($cs + $gap) - $gap
    $prevW   = 4 * ($cs + $gap) - $gap
    $sideW   = [Math]::Max($prevW, 110) + 20
    $PW      = $boardW + $script:SIDE_PAD + $sideW
    $TH      = $script:TOP_HEIGHT

    $frm.SuspendLayout()
    $frm.ClientSize  = [System.Drawing.Size]::new($PW, $boardH + $TH)
    $tb.Width        = $PW
    $gp.Size         = [System.Drawing.Size]::new($PW, $boardH)
    $bNew.Location   = [System.Drawing.Point]::new($PW - 123, 12)
    $bSet.Location   = [System.Drawing.Point]::new($PW - 247, 12)
    $bPause.Location = [System.Drawing.Point]::new($PW - 371, 12)
    $hintLbl.Width   = [Math]::Max(10, $PW - 500)
    $frm.ResumeLayout()
}

# ------------------------------------------------------------------
#  Skip UI when dot-sourced for testing
# ------------------------------------------------------------------
if ($script:TetrisTestMode) { return }

# ------------------------------------------------------------------
#  COMPUTE INITIAL SIZES
# ------------------------------------------------------------------
script:CalcCellSize
$cs      = $script:CELL
$gap     = $script:GAP
$boardW  = $script:COLS * ($cs + $gap) - $gap
$boardH  = $script:ROWS * ($cs + $gap) - $gap
$prevW   = 4 * ($cs + $gap) - $gap
$sideW   = [Math]::Max($prevW, 110) + 20
$PW      = $boardW + $script:SIDE_PAD + $sideW
$TOP     = $script:TOP_HEIGHT

# ------------------------------------------------------------------
#  CUSTOM TYPES
# ------------------------------------------------------------------
$wfPath  = [System.Windows.Forms.Form].Assembly.Location
$drwPath = [System.Drawing.Color].Assembly.Location

if (-not ([System.Management.Automation.PSTypeName]'TetrisPanel').Type) {
    Add-Type -TypeDefinition @"
using System.Windows.Forms;
public class TetrisPanel : Panel {
    public TetrisPanel() { DoubleBuffered = true; TabStop = false; }
}
"@ -ReferencedAssemblies $wfPath, $drwPath -WarningAction SilentlyContinue
}

if (-not ([System.Management.Automation.PSTypeName]'TetrisKeyFilter').Type) {
    Add-Type -TypeDefinition @"
using System.Windows.Forms;
// Plain form subclass.  FireKeyDown lets TetrisKeyFilter raise KeyDown without
// needing a custom event (avoids PowerShell delegate-bridging issues).
public class TetrisGame : Form {
    public string GameTitle { get { return "Tetris"; } }
    public void FireKeyDown(Keys k) { OnKeyDown(new KeyEventArgs(k)); }
}
// Application-level message filter — intercepts WM_KEYDOWN before any control.
// Suppressed while a modal dialog is open (_form.Enabled == false).
public class TetrisKeyFilter : IMessageFilter {
    private TetrisGame _form;
    public TetrisKeyFilter(TetrisGame f) { _form = f; }
    public bool PreFilterMessage(ref Message m) {
        if (m.Msg == 0x0100 && _form.Enabled) {
            Keys k = (Keys)(int)m.WParam & Keys.KeyCode;
            switch (k) {
                case Keys.Left:  case Keys.Right: case Keys.Up:   case Keys.Down:
                case Keys.Space: case Keys.Z:     case Keys.P:    case Keys.N:
                case Keys.S:
                    _form.FireKeyDown(k);
                    return true;
            }
        }
        return false;
    }
}
"@ -ReferencedAssemblies $wfPath, $drwPath
}

# ------------------------------------------------------------------
#  FORM
# ------------------------------------------------------------------
$form = [TetrisGame]::new()
$form.Icon            = script:MakeIcon
$form.Text            = "Tetris - PowerShell Edition"
$form.BackColor       = [System.Drawing.Color]::FromArgb(18, 18, 28)
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
$form.MaximizeBox     = $false
$form.StartPosition   = [System.Windows.Forms.FormStartPosition]::CenterScreen
$form.ClientSize      = [System.Drawing.Size]::new($PW, $boardH + $TOP)
$form.Font            = [System.Drawing.Font]::new("Segoe UI", 10)

# ------------------------------------------------------------------
#  TOP BAR
# ------------------------------------------------------------------
$topBar           = [System.Windows.Forms.Panel]::new()
$topBar.Size      = [System.Drawing.Size]::new($PW, $TOP)
$topBar.Location  = [System.Drawing.Point]::new(0, 0)
$topBar.BackColor = [System.Drawing.Color]::FromArgb(14, 14, 24)

$lblHint              = [System.Windows.Forms.Label]::new()
$lblHint.Text         = "Arrow keys: move/rotate  |  Space: hard drop  |  P: pause"
$lblHint.ForeColor    = [System.Drawing.Color]::FromArgb(130, 195, 130)
$lblHint.Font         = [System.Drawing.Font]::new("Segoe UI", 9)
$lblHint.AutoSize     = $false
$lblHint.AutoEllipsis = $true
$lblHint.Size         = [System.Drawing.Size]::new([Math]::Max(10, $PW - 500), 46)
$lblHint.Location     = [System.Drawing.Point]::new(10, 4)

$btnNew                            = [System.Windows.Forms.Button]::new()
$btnNew.Text                       = "New Game  [N]"
$btnNew.Font                       = [System.Drawing.Font]::new("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$btnNew.ForeColor                  = [System.Drawing.Color]::White
$btnNew.BackColor                  = [System.Drawing.Color]::FromArgb(50, 90, 168)
$btnNew.FlatStyle                  = [System.Windows.Forms.FlatStyle]::Flat
$btnNew.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(70, 120, 210)
$btnNew.FlatAppearance.BorderSize  = 1
$btnNew.Size                       = [System.Drawing.Size]::new(115, 30)
$btnNew.Location                   = [System.Drawing.Point]::new($PW - 123, 12)
$btnNew.Cursor                     = [System.Windows.Forms.Cursors]::Hand

$btnSettings                            = [System.Windows.Forms.Button]::new()
$btnSettings.Text                       = "Settings  [S]"
$btnSettings.Font                       = [System.Drawing.Font]::new("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$btnSettings.ForeColor                  = [System.Drawing.Color]::White
$btnSettings.BackColor                  = [System.Drawing.Color]::FromArgb(55, 55, 85)
$btnSettings.FlatStyle                  = [System.Windows.Forms.FlatStyle]::Flat
$btnSettings.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(80, 80, 120)
$btnSettings.FlatAppearance.BorderSize  = 1
$btnSettings.Size                       = [System.Drawing.Size]::new(115, 30)
$btnSettings.Location                   = [System.Drawing.Point]::new($PW - 247, 12)
$btnSettings.Cursor                     = [System.Windows.Forms.Cursors]::Hand

$btnPause                            = [System.Windows.Forms.Button]::new()
$btnPause.Text                       = "Pause  [P]"
$btnPause.Font                       = [System.Drawing.Font]::new("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$btnPause.ForeColor                  = [System.Drawing.Color]::White
$btnPause.BackColor                  = [System.Drawing.Color]::FromArgb(55, 85, 55)
$btnPause.FlatStyle                  = [System.Windows.Forms.FlatStyle]::Flat
$btnPause.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(80, 120, 80)
$btnPause.FlatAppearance.BorderSize  = 1
$btnPause.Size                       = [System.Drawing.Size]::new(115, 30)
$btnPause.Location                   = [System.Drawing.Point]::new($PW - 371, 12)
$btnPause.Cursor                     = [System.Windows.Forms.Cursors]::Hand

$topBar.Controls.AddRange(@($lblHint, $btnPause, $btnSettings, $btnNew))

# ------------------------------------------------------------------
#  GAME PANEL
# ------------------------------------------------------------------
$gamePanel          = [TetrisPanel]::new()
$gamePanel.Size     = [System.Drawing.Size]::new($PW, $boardH)
$gamePanel.Location = [System.Drawing.Point]::new(0, $TOP)

$form.Controls.AddRange(@($topBar, $gamePanel))

# ------------------------------------------------------------------
#  GAME TIMER
# ------------------------------------------------------------------
$script:gameTimer          = [System.Windows.Forms.Timer]::new()
$script:gameTimer.Interval = $script:LEVEL_SPEEDS[0]

# ------------------------------------------------------------------
#  EVENT HANDLERS
# ------------------------------------------------------------------

# Update top-bar hint with current status
$script:UpdateHint = {
    param([string]$msg)
    $lblHint.Text = $msg
}

# Lock piece, clear lines, score, spawn next; returns $false if game over
$script:LockAndSpawn = {
    $tSpin = script:GetTSpinType   # detect before locking (board still clear of this piece)
    script:LockPiece
    $n = script:ClearLines
    script:AddScore $n 0 0 $tSpin
    script:SpawnPiece
    $chk = script:GetCells $script:curType $script:curRot $script:curRow $script:curCol
    if (-not (script:IsValid $chk)) {
        $script:gameOver = $true
        $script:gameTimer.Stop()
        $lblHint.Text = "  Game Over!  Score: $($script:score)  |  Press N for a new game."
        return $false
    }
    return $true
}

# Gravity tick
$script:gameTimer.Add_Tick({
    if ($script:gameOver -or $script:paused) { return }
    if (-not (script:TryMove 1 0)) {
        & $script:LockAndSpawn | Out-Null
    }
    $gamePanel.Invalidate()
})

# New game
$script:StartNewGame = {
    $script:board = New-Object 'int[,]' $script:ROWS, $script:COLS
    for ($r = 0; $r -lt $script:ROWS; $r++) {
        for ($c = 0; $c -lt $script:COLS; $c++) {
            $script:board[$r, $c] = $script:EMPTY
        }
    }
    $script:score         = 0
    $script:level         = $script:START_LEVEL
    $script:lines         = 0
    $script:combo         = -1
    $script:b2b           = $false
    $script:lastWasRotate = $false
    $script:gameOver      = $false
    $script:paused        = $false
    $script:nextType = Get-Random -Minimum 0 -Maximum 7
    script:SpawnPiece
    $script:gameTimer.Stop()
    $idx = [Math]::Min($script:level - 1, 10)
    $script:gameTimer.Interval = $script:LEVEL_SPEEDS[$idx]
    $script:gameTimer.Start()
    $btnPause.Text = "Pause  [P]"
    $lblHint.Text  = "  Arrow keys: move/rotate  |  Space: hard drop  |  P: pause"
    $gamePanel.Invalidate()
}

# Settings dialog
$script:ShowSettings = {
    if (-not $form.Enabled) { return }   # already showing a modal dialog
    $wasRunning = (-not $script:gameOver -and -not $script:paused)
    $script:paused = $true
    $script:gameTimer.Stop()

    $dlg = [System.Windows.Forms.Form]::new()
    $dlg.Text            = "Settings"
    $dlg.ClientSize      = [System.Drawing.Size]::new(380, 328)
    $dlg.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $dlg.MaximizeBox     = $false
    $dlg.MinimizeBox     = $false
    $dlg.StartPosition   = [System.Windows.Forms.FormStartPosition]::CenterParent
    $dlg.BackColor       = [System.Drawing.Color]::FromArgb(26, 26, 40)
    $dlg.ForeColor       = [System.Drawing.Color]::FromArgb(215, 215, 245)
    $dlg.Font            = [System.Drawing.Font]::new("Segoe UI", 10)

    # Board Size group
    $gbGrid           = [System.Windows.Forms.GroupBox]::new()
    $gbGrid.Text      = "Board Size"
    $gbGrid.Size      = [System.Drawing.Size]::new(352, 100)
    $gbGrid.Location  = [System.Drawing.Point]::new(12, 10)
    $gbGrid.ForeColor = [System.Drawing.Color]::FromArgb(170, 170, 230)

    $lblCols           = [System.Windows.Forms.Label]::new()
    $lblCols.Text      = "Columns:"
    $lblCols.AutoSize  = $true
    $lblCols.Location  = [System.Drawing.Point]::new(14, 34)
    $lblCols.ForeColor = [System.Drawing.Color]::FromArgb(215, 215, 245)

    $nudCols           = [System.Windows.Forms.NumericUpDown]::new()
    $nudCols.Minimum   = 6
    $nudCols.Maximum   = 16
    $nudCols.Value     = $script:COLS
    $nudCols.Location  = [System.Drawing.Point]::new(90, 31)
    $nudCols.Width     = 58
    $nudCols.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 62)
    $nudCols.ForeColor = [System.Drawing.Color]::FromArgb(215, 215, 245)

    $lblRows           = [System.Windows.Forms.Label]::new()
    $lblRows.Text      = "Rows:"
    $lblRows.AutoSize  = $true
    $lblRows.Location  = [System.Drawing.Point]::new(170, 34)
    $lblRows.ForeColor = [System.Drawing.Color]::FromArgb(215, 215, 245)

    $nudRows           = [System.Windows.Forms.NumericUpDown]::new()
    $nudRows.Minimum   = 12
    $nudRows.Maximum   = 26
    $nudRows.Value     = $script:ROWS
    $nudRows.Location  = [System.Drawing.Point]::new(220, 31)
    $nudRows.Width     = 58
    $nudRows.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 62)
    $nudRows.ForeColor = [System.Drawing.Color]::FromArgb(215, 215, 245)

    $lblNote           = [System.Windows.Forms.Label]::new()
    $lblNote.Text      = "Standard: 10 cols x 20 rows"
    $lblNote.AutoSize  = $true
    $lblNote.Location  = [System.Drawing.Point]::new(14, 68)
    $lblNote.ForeColor = [System.Drawing.Color]::FromArgb(120, 120, 175)
    $lblNote.Font      = [System.Drawing.Font]::new("Segoe UI", 8)

    $gbGrid.Controls.AddRange(@($lblCols, $nudCols, $lblRows, $nudRows, $lblNote))

    # Starting Level group
    $gbLevel           = [System.Windows.Forms.GroupBox]::new()
    $gbLevel.Text      = "Starting Level"
    $gbLevel.Size      = [System.Drawing.Size]::new(352, 80)
    $gbLevel.Location  = [System.Drawing.Point]::new(12, 118)
    $gbLevel.ForeColor = [System.Drawing.Color]::FromArgb(170, 170, 230)

    $lblSL           = [System.Windows.Forms.Label]::new()
    $lblSL.Text      = "Level:"
    $lblSL.AutoSize  = $true
    $lblSL.Location  = [System.Drawing.Point]::new(14, 34)
    $lblSL.ForeColor = [System.Drawing.Color]::FromArgb(215, 215, 245)

    $nudLevel           = [System.Windows.Forms.NumericUpDown]::new()
    $nudLevel.Minimum   = 1
    $nudLevel.Maximum   = 10
    $nudLevel.Value     = $script:START_LEVEL
    $nudLevel.Location  = [System.Drawing.Point]::new(76, 31)
    $nudLevel.Width     = 58
    $nudLevel.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 62)
    $nudLevel.ForeColor = [System.Drawing.Color]::FromArgb(215, 215, 245)

    $lblLN           = [System.Windows.Forms.Label]::new()
    $lblLN.Text      = "(1 = slowest,  10 = fastest)"
    $lblLN.AutoSize  = $true
    $lblLN.Location  = [System.Drawing.Point]::new(148, 34)
    $lblLN.ForeColor = [System.Drawing.Color]::FromArgb(120, 120, 175)
    $lblLN.Font      = [System.Drawing.Font]::new("Segoe UI", 8)

    $gbLevel.Controls.AddRange(@($lblSL, $nudLevel, $lblLN))

    # Difficulty Modifiers group
    $gbDiff           = [System.Windows.Forms.GroupBox]::new()
    $gbDiff.Text      = "Difficulty Modifiers  (score bonuses apply from new game)"
    $gbDiff.Size      = [System.Drawing.Size]::new(352, 80)
    $gbDiff.Location  = [System.Drawing.Point]::new(12, 206)
    $gbDiff.ForeColor = [System.Drawing.Color]::FromArgb(170, 170, 230)

    $chkNoGhost           = [System.Windows.Forms.CheckBox]::new()
    $chkNoGhost.Text      = "No ghost piece  (+50% line score)"
    $chkNoGhost.Checked   = $script:NO_GHOST
    $chkNoGhost.Location  = [System.Drawing.Point]::new(14, 24)
    $chkNoGhost.AutoSize  = $true
    $chkNoGhost.ForeColor = [System.Drawing.Color]::FromArgb(215, 215, 245)

    $chkHideNext           = [System.Windows.Forms.CheckBox]::new()
    $chkHideNext.Text      = "Hide next piece  (+25% line score)"
    $chkHideNext.Checked   = $script:HIDE_NEXT
    $chkHideNext.Location  = [System.Drawing.Point]::new(14, 50)
    $chkHideNext.AutoSize  = $true
    $chkHideNext.ForeColor = [System.Drawing.Color]::FromArgb(215, 215, 245)

    $gbDiff.Controls.AddRange(@($chkNoGhost, $chkHideNext))

    # Action buttons
    $btnApply           = [System.Windows.Forms.Button]::new()
    $btnApply.Text      = "Apply && New Game"
    $btnApply.Size      = [System.Drawing.Size]::new(168, 32)
    $btnApply.Location  = [System.Drawing.Point]::new(12, 282)
    $btnApply.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnApply.BackColor = [System.Drawing.Color]::FromArgb(50, 90, 168)
    $btnApply.ForeColor = [System.Drawing.Color]::White
    $btnApply.Font      = [System.Drawing.Font]::new("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $btnApply.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(70, 120, 210)
    $btnApply.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $btnApply.Cursor    = [System.Windows.Forms.Cursors]::Hand

    $btnCancel           = [System.Windows.Forms.Button]::new()
    $btnCancel.Text      = "Cancel"
    $btnCancel.Size      = [System.Drawing.Size]::new(88, 32)
    $btnCancel.Location  = [System.Drawing.Point]::new(190, 282)
    $btnCancel.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnCancel.BackColor = [System.Drawing.Color]::FromArgb(52, 52, 72)
    $btnCancel.ForeColor = [System.Drawing.Color]::FromArgb(200, 200, 220)
    $btnCancel.Font      = [System.Drawing.Font]::new("Segoe UI", 9)
    $btnCancel.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(82, 82, 112)
    $btnCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $btnCancel.Cursor    = [System.Windows.Forms.Cursors]::Hand

    $dlg.AcceptButton = $btnApply
    $dlg.CancelButton = $btnCancel
    $dlg.Controls.AddRange(@($gbGrid, $gbLevel, $gbDiff, $btnApply, $btnCancel))

    if ($dlg.ShowDialog($form) -eq [System.Windows.Forms.DialogResult]::OK) {
        $script:COLS        = [int]$nudCols.Value
        $script:ROWS        = [int]$nudRows.Value
        $script:START_LEVEL = [int]$nudLevel.Value
        $script:NO_GHOST    = $chkNoGhost.Checked
        $script:HIDE_NEXT   = $chkHideNext.Checked
        script:CalcCellSize
        script:ResizeUI $form $topBar $gamePanel $btnNew $btnSettings $btnPause $lblHint
        & $script:StartNewGame
    } else {
        if ($wasRunning) {
            $script:paused = $false
            $script:gameTimer.Start()
            $gamePanel.Invalidate()
        }
    }
    $dlg.Dispose()
    $form.Focus() | Out-Null
}

$btnNew.Add_Click($script:StartNewGame)
$btnSettings.Add_Click($script:ShowSettings)

$btnPause.Add_Click({
    if ($script:gameOver) { return }
    if ($script:paused) {
        $script:paused = $false
        $script:gameTimer.Start()
        $btnPause.Text = "Pause  [P]"
    } else {
        $script:paused = $true
        $script:gameTimer.Stop()
        $btnPause.Text = "Resume [P]"
    }
    $gamePanel.Invalidate()
})

$form.Add_KeyDown({
    param($s, $e)
    $k = $e.KeyCode
    $Keys = [System.Windows.Forms.Keys]

    if ($k -eq $Keys::N) {
        & $script:StartNewGame
    } elseif ($k -eq $Keys::S) {
        & $script:ShowSettings
    } elseif ($k -eq $Keys::P) {
        if ($script:gameOver) { return }
        if ($script:paused) {
            $script:paused = $false
            $script:gameTimer.Start()
            $btnPause.Text = "Pause  [P]"
        } else {
            $script:paused = $true
            $script:gameTimer.Stop()
            $btnPause.Text = "Resume [P]"
        }
        $gamePanel.Invalidate()
    } elseif ($k -eq $Keys::Left) {
        if ($script:gameOver -or $script:paused) { return }
        if (script:TryMove 0 -1) { $gamePanel.Invalidate() }
    } elseif ($k -eq $Keys::Right) {
        if ($script:gameOver -or $script:paused) { return }
        if (script:TryMove 0 1)  { $gamePanel.Invalidate() }
    } elseif ($k -eq $Keys::Down) {
        if ($script:gameOver -or $script:paused) { return }
        if (script:TryMove 1 0) {
            script:AddScore 0 1 0
            $gamePanel.Invalidate()
        }
    } elseif ($k -eq $Keys::Up) {
        if ($script:gameOver -or $script:paused) { return }
        if (script:TryRotate 1) { $gamePanel.Invalidate() }
    } elseif ($k -eq $Keys::Z) {
        if ($script:gameOver -or $script:paused) { return }
        if (script:TryRotate -1) { $gamePanel.Invalidate() }
    } elseif ($k -eq $Keys::Space) {
        if ($script:gameOver -or $script:paused) { return }
        $dropped = script:DoHardDrop
        & $script:LockAndSpawn | Out-Null
        script:AddScore 0 0 $dropped
        $gamePanel.Invalidate()
    }
})

$script:keyFilter = [TetrisKeyFilter]::new($form)
[System.Windows.Forms.Application]::AddMessageFilter($script:keyFilter)
$form.Add_FormClosed({ [System.Windows.Forms.Application]::RemoveMessageFilter($script:keyFilter) })

$gamePanel.Add_Paint({
    param($s, $e)
    script:PaintBoard $e
})

# ------------------------------------------------------------------
#  START
# ------------------------------------------------------------------
[System.Windows.Forms.Application]::EnableVisualStyles()
& $script:StartNewGame
# Use ShowDialog when a message loop is already running (e.g. PowerShell ISE),
# otherwise use Application::Run for a normal console launch.
if ([System.Windows.Forms.Application]::MessageLoop) {
    $form.ShowDialog() | Out-Null
} else {
    [System.Windows.Forms.Application]::Run($form)
}
