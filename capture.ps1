Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$src = @"
using System;
using System.Runtime.InteropServices;
using System.Drawing;
using System.Drawing.Imaging;
public class WinCapture {
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint f);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint msg, IntPtr wParam, IntPtr lParam);
    [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr h, uint msg, IntPtr wParam, IntPtr lParam);
    [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern void mouse_event(uint flags, int dx, int dy, uint data, UIntPtr extra);
    public static void PressKey(byte vk) {
        keybd_event(vk, 0, 0, UIntPtr.Zero);
        keybd_event(vk, 0, 2, UIntPtr.Zero);
    }
    public static void MouseClick(int x, int y) {
        SetCursorPos(x, y);
        mouse_event(0x0002, 0, 0, 0, UIntPtr.Zero);  // MOUSEEVENTF_LEFTDOWN
        mouse_event(0x0004, 0, 0, 0, UIntPtr.Zero);  // MOUSEEVENTF_LEFTUP
    }
    [DllImport("user32.dll")] public static extern IntPtr FindWindow(string cls, string title);
    [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr parent, EnumChildProc cb, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumChildProc cb, IntPtr lParam);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll", CharSet=CharSet.Auto)] public static extern int GetWindowText(IntPtr h, System.Text.StringBuilder sb, int max);
    public delegate bool EnumChildProc(IntPtr hwnd, IntPtr lParam);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }

    private static IntPtr _foundChild;
    private static string _targetTitle;
    private static uint   _targetPid;
    private static IntPtr _excludeHwnd;
    private static bool FindDialogCallback(IntPtr hwnd, IntPtr lParam) {
        if (hwnd == _excludeHwnd || !IsWindowVisible(hwnd)) return true;
        uint pid; GetWindowThreadProcessId(hwnd, out pid);
        if (pid != _targetPid) return true;
        var sb = new System.Text.StringBuilder(256);
        GetWindowText(hwnd, sb, 256);
        if (sb.Length == 0) return true;   // skip untitled windows
        _foundChild = hwnd;
        return false;   // stop at first titled, visible, in-process window
    }
    public static IntPtr FindDialogForProcess(uint pid, IntPtr mainHwnd) {
        _targetPid   = pid;
        _excludeHwnd = mainHwnd;
        _foundChild  = IntPtr.Zero;
        EnumWindows(FindDialogCallback, IntPtr.Zero);
        return _foundChild;
    }
    private static bool ChildSearchCallback(IntPtr hwnd, IntPtr lParam) {
        var sb = new System.Text.StringBuilder(256);
        GetWindowText(hwnd, sb, 256);
        if (sb.ToString() == _targetTitle) { _foundChild = hwnd; return false; }
        return true;
    }
    public static IntPtr FindChildByTitle(IntPtr parent, string title) {
        _foundChild = IntPtr.Zero;
        _targetTitle = title;
        EnumChildWindows(parent, ChildSearchCallback, IntPtr.Zero);
        return _foundChild;
    }

    const uint WM_KEYDOWN = 0x0100;
    const uint WM_KEYUP   = 0x0101;

    public static Bitmap Capture(IntPtr hwnd) {
        RECT r; GetWindowRect(hwnd, out r);
        int w = r.Right - r.Left, h = r.Bottom - r.Top;
        var bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb);
        using (var g = Graphics.FromImage(bmp)) {
            IntPtr hdc = g.GetHdc();
            PrintWindow(hwnd, hdc, 2);
            g.ReleaseHdc(hdc);
        }
        return bmp;
    }

    public static void SendKey(IntPtr hwnd, int vk) {
        PostMessage(hwnd, WM_KEYDOWN, new IntPtr(vk), IntPtr.Zero);
        PostMessage(hwnd, WM_KEYUP,   new IntPtr(vk), IntPtr.Zero);
    }
}
"@
$drwPath = [System.Drawing.Bitmap].Assembly.Location
Add-Type -TypeDefinition $src -ReferencedAssemblies $drwPath

$outDir = "D:/stringsn88keys/tetrispowershell/screenshots"

$proc = Start-Process powershell.exe `
    -ArgumentList '-ExecutionPolicy Bypass -File "D:/stringsn88keys/tetrispowershell/Tetris.ps1"' `
    -PassThru

# Poll up to 10 s for the window handle
$hwnd = [IntPtr]::Zero
for ($i = 0; $i -lt 20; $i++) {
    Start-Sleep -Milliseconds 500
    $proc.Refresh()
    if ($proc.MainWindowHandle -ne [IntPtr]::Zero) { $hwnd = $proc.MainWindowHandle; break }
}
if ($hwnd -eq [IntPtr]::Zero) { Write-Host "ERROR: no window"; $proc.Kill(); exit 1 }

[WinCapture]::SetForegroundWindow($hwnd) | Out-Null
Start-Sleep -Milliseconds 1200

# --- 1. gameplay.png (piece falling, ghost piece visible) ---
$bmp = [WinCapture]::Capture($hwnd)
$bmp.Save("$outDir/gameplay.png", [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Host "gameplay.png saved"

# --- 2. paused.png (press P to pause) ---
$VK_P = 0x50
[WinCapture]::SendKey($hwnd, $VK_P)
Start-Sleep -Milliseconds 600
$bmp = [WinCapture]::Capture($hwnd)
$bmp.Save("$outDir/paused.png", [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Host "paused.png saved"

# --- 3. settings.png (mouse-click the Settings button to open the dialog) ---
$btnHwnd = [WinCapture]::FindChildByTitle($hwnd, "Settings  [S]")
if ($btnHwnd -eq [IntPtr]::Zero) { Write-Host "ERROR: Settings button not found"; $proc.Kill(); exit 1 }
$br = New-Object WinCapture+RECT
[WinCapture]::GetWindowRect($btnHwnd, [ref]$br) | Out-Null
$cx = [int](($br.Left + $br.Right)  / 2)
$cy = [int](($br.Top  + $br.Bottom) / 2)
Write-Host "Button rect: $($br.Left),$($br.Top)-$($br.Right),$($br.Bottom)  click:$cx,$cy"
[WinCapture]::MouseClick($cx, $cy)
Start-Sleep -Milliseconds 400

# Find the Settings dialog by enumerating windows owned by the game process
$dlgHwnd = [IntPtr]::Zero
for ($i = 0; $i -lt 20; $i++) {
    Start-Sleep -Milliseconds 200
    $h = [WinCapture]::FindDialogForProcess([UInt32]$proc.Id, $hwnd)
    if ($h -ne [IntPtr]::Zero) { $dlgHwnd = $h; break }
}
if ($dlgHwnd -eq [IntPtr]::Zero) { Write-Host "ERROR: Settings dialog not found"; $proc.Kill(); exit 1 }

Start-Sleep -Milliseconds 300
$bmp = [WinCapture]::Capture($dlgHwnd)
$bmp.Save("$outDir/settings.png", [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Host "settings.png saved"

# Close dialog with Escape, then close the game
$VK_ESCAPE = 0x1B
[WinCapture]::SendKey($dlgHwnd, $VK_ESCAPE)
Start-Sleep -Milliseconds 400
$proc.CloseMainWindow() | Out-Null
Write-Host "Done"
