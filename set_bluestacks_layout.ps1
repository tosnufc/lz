param()

Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;

public class Win32Pos {
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc enumProc, IntPtr lParam);
    [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);
    [DllImport("user32.dll")] public static extern int GetWindowTextLength(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool IsZoomed(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
    [DllImport("user32.dll")] public static extern bool GetWindowPlacement(IntPtr hWnd, ref WINDOWPLACEMENT lpwndpl);
    [DllImport("user32.dll")] public static extern bool SetWindowPlacement(IntPtr hWnd, ref WINDOWPLACEMENT lpwndpl);
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
    public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
    public struct POINT { public int X; public int Y; }
    public struct WINDOWPLACEMENT {
        public int length;
        public int flags;
        public int showCmd;
        public POINT ptMinPosition;
        public POINT ptMaxPosition;
        public RECT rcNormalPosition;
    }
}
"@

# NOTE: We intentionally do NOT force our own process's DPI awareness context here.
# Testing showed that explicitly setting SetProcessDpiAwarenessContext introduced
# inconsistent per-window scaling errors (each BlueStacks instance scaled
# differently - 120%, 133%, etc.) that were worse than leaving the calling
# process at its default (DPI-unaware) context, which works correctly and
# consistently across all 4 windows.

# ---- Target layout (fixed values) ----
$layout = @{
    "farm-1" = @{ Left = 0;   Top = 3; Width = 312; Height = 585 }
    "farm-2" = @{ Left = 312; Top = 3; Width = 312; Height = 585 }
    "farm-3" = @{ Left = 624; Top = 3; Width = 344; Height = 585 }
    "farm-4" = @{ Left = 968; Top = 3; Width = 312; Height = 585 }
}

$SW_RESTORE = 9
$SW_SHOWNORMAL = 1
$SWP_NOZORDER = 0x0004
$SWP_NOACTIVATE = 0x0010
$HWND_TOP = [IntPtr]::Zero
$MAX_ATTEMPTS = 10
$RETRY_DELAY_MS = 150

function Find-TargetWindows {
    param($layoutKeys)

    $found = @{}
    $callback = {
        param($hWnd, $lParam)
        if ([Win32Pos]::IsWindowVisible($hWnd)) {
            $len = [Win32Pos]::GetWindowTextLength($hWnd)
            if ($len -gt 0) {
                $sb = New-Object System.Text.StringBuilder ($len + 1)
                [Win32Pos]::GetWindowText($hWnd, $sb, $sb.Capacity) | Out-Null
                $title = $sb.ToString()

                if ($script:layoutKeys -contains $title) {
                    $procId = 0
                    [Win32Pos]::GetWindowThreadProcessId($hWnd, [ref]$procId) | Out-Null
                    $procName = (Get-Process -Id $procId -ErrorAction SilentlyContinue).ProcessName
                    # Only match BlueStacks player windows, exact title match, to avoid
                    # accidentally moving an unrelated window with the same title.
                    if ($procName -eq "HD-Player") {
                        $script:found[$title] = $hWnd
                    }
                }
            }
        }
        return $true
    }

    $script:found = $found
    $script:layoutKeys = $layoutKeys
    [Win32Pos]::EnumWindows($callback, [IntPtr]::Zero) | Out-Null
    return $script:found
}

$found = Find-TargetWindows -layoutKeys $layout.Keys

foreach ($name in $layout.Keys) {
    if (-not $found.ContainsKey($name)) {
        Write-Output "MISSING: Window titled '$name' (process HD-Player) was not found. Is it running?"
        continue
    }

    $hWnd = $found[$name]
    $target = $layout[$name]
    $success = $false

    for ($attempt = 1; $attempt -le $MAX_ATTEMPTS; $attempt++) {

        # Un-maximize/un-minimize if needed before resizing/repositioning.
        if ([Win32Pos]::IsIconic($hWnd) -or [Win32Pos]::IsZoomed($hWnd)) {
            [Win32Pos]::ShowWindow($hWnd, $SW_RESTORE) | Out-Null
            Start-Sleep -Milliseconds $RETRY_DELAY_MS
        }

        # Use SetWindowPlacement (not just SetWindowPos) to explicitly overwrite
        # the window's stored "normal position" / snap state. Windows can silently
        # revert a SetWindowPos-only move back to a previously snapped/remembered
        # position shortly after, if the window's internal placement history
        # (e.g. Aero Snap state) isn't also cleared. SetWindowPlacement fixes this
        # by directly rewriting rcNormalPosition and forcing showCmd=NORMAL.
        $placement = New-Object Win32Pos+WINDOWPLACEMENT
        $placement.length = [System.Runtime.InteropServices.Marshal]::SizeOf([type]"Win32Pos+WINDOWPLACEMENT")
        [Win32Pos]::GetWindowPlacement($hWnd, [ref]$placement) | Out-Null

        $placement.showCmd = $SW_SHOWNORMAL
        $placement.flags = 0
        $placement.rcNormalPosition.Left = $target.Left
        $placement.rcNormalPosition.Top = $target.Top
        $placement.rcNormalPosition.Right = $target.Left + $target.Width
        $placement.rcNormalPosition.Bottom = $target.Top + $target.Height

        [Win32Pos]::SetWindowPlacement($hWnd, [ref]$placement) | Out-Null
        Start-Sleep -Milliseconds $RETRY_DELAY_MS

        # Follow up with SetWindowPos as a belt-and-suspenders nudge, in case
        # SetWindowPlacement alone wasn't enough to trigger an immediate redraw.
        [Win32Pos]::SetWindowPos($hWnd, $HWND_TOP, $target.Left, $target.Top, $target.Width, $target.Height, ($SWP_NOZORDER -bor $SWP_NOACTIVATE)) | Out-Null
        Start-Sleep -Milliseconds $RETRY_DELAY_MS

        # Verify the window actually landed where we told it to.
        $rect = New-Object Win32Pos+RECT
        [Win32Pos]::GetWindowRect($hWnd, [ref]$rect) | Out-Null
        $actualW = $rect.Right - $rect.Left
        $actualH = $rect.Bottom - $rect.Top

        if ($rect.Left -eq $target.Left -and $rect.Top -eq $target.Top -and $actualW -eq $target.Width -and $actualH -eq $target.Height) {
            Write-Output "OK   : $name -> Left=$($target.Left) Top=$($target.Top) Width=$($target.Width) Height=$($target.Height) (attempt $attempt)"
            $success = $true
            break
        }
    }

    if (-not $success) {
        Write-Output "FAIL : $name -> Could not reach target after $MAX_ATTEMPTS attempts. Last actual: Left=$($rect.Left) Top=$($rect.Top) Width=$actualW Height=$actualH"
    }
}
