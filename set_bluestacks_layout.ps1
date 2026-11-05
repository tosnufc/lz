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
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
}
"@

# ---- Target layout (fixed values) ----
$layout = @{
    "farm-1" = @{ Left = 0;   Top = 3; Width = 312; Height = 585 }
    "farm-2" = @{ Left = 312; Top = 3; Width = 312; Height = 585 }
    "farm-3" = @{ Left = 624; Top = 3; Width = 344; Height = 585 }
    "farm-4" = @{ Left = 968; Top = 3; Width = 312; Height = 585 }
}

$SW_RESTORE = 9
$SWP_NOZORDER = 0x0004
$SWP_NOACTIVATE = 0x0010
$HWND_TOP = [IntPtr]::Zero

$found = @{}

$callback = {
    param($hWnd, $lParam)
    if ([Win32Pos]::IsWindowVisible($hWnd)) {
        $len = [Win32Pos]::GetWindowTextLength($hWnd)
        if ($len -gt 0) {
            $sb = New-Object System.Text.StringBuilder ($len + 1)
            [Win32Pos]::GetWindowText($hWnd, $sb, $sb.Capacity) | Out-Null
            $title = $sb.ToString()

            if ($script:layout.ContainsKey($title)) {
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

[Win32Pos]::EnumWindows($callback, [IntPtr]::Zero) | Out-Null

foreach ($name in $layout.Keys) {
    if ($found.ContainsKey($name)) {
        $hWnd = $found[$name]
        $rect = $layout[$name]

        # Make sure window is in normal (not maximized/minimized) state first,
        # otherwise SetWindowPos size/position can be ignored or distorted.
        [Win32Pos]::ShowWindow($hWnd, $SW_RESTORE) | Out-Null
        Start-Sleep -Milliseconds 100

        $ok = [Win32Pos]::SetWindowPos($hWnd, $HWND_TOP, $rect.Left, $rect.Top, $rect.Width, $rect.Height, ($SWP_NOZORDER -bor $SWP_NOACTIVATE))

        if ($ok) {
            Write-Output "OK   : $name -> Left=$($rect.Left) Top=$($rect.Top) Width=$($rect.Width) Height=$($rect.Height)"
        } else {
            Write-Output "FAIL : $name -> SetWindowPos returned false"
        }
    } else {
        Write-Output "MISSING: Window titled '$name' (process HD-Player) was not found. Is it running?"
    }
}
