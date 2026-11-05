Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;
using System.Collections.Generic;

public class Win32 {
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc enumProc, IntPtr lParam);
    [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);
    [DllImport("user32.dll")] public static extern int GetWindowTextLength(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
    public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
}
"@

$results = New-Object System.Collections.Generic.List[Object]

$callback = {
    param($hWnd, $lParam)
    if ([Win32]::IsWindowVisible($hWnd)) {
        $len = [Win32]::GetWindowTextLength($hWnd)
        if ($len -gt 0) {
            $sb = New-Object System.Text.StringBuilder ($len + 1)
            [Win32]::GetWindowText($hWnd, $sb, $sb.Capacity) | Out-Null
            $title = $sb.ToString()
            $rect = New-Object Win32+RECT
            [Win32]::GetWindowRect($hWnd, [ref]$rect) | Out-Null
            $procId = 0
            [Win32]::GetWindowThreadProcessId($hWnd, [ref]$procId) | Out-Null
            try { $procName = (Get-Process -Id $procId -ErrorAction SilentlyContinue).ProcessName } catch { $procName = "?" }
            $obj = [PSCustomObject]@{
                Title = $title
                Process = $procName
                PID = $procId
                Left = $rect.Left
                Top = $rect.Top
                Right = $rect.Right
                Bottom = $rect.Bottom
                Width = $rect.Right - $rect.Left
                Height = $rect.Bottom - $rect.Top
            }
            $script:results.Add($obj)
        }
    }
    return $true
}

[Win32]::EnumWindows($callback, [IntPtr]::Zero) | Out-Null

$results | Where-Object { $_.Process -match "HD-Player|BlueStacks" -or $_.Title -match "BlueStacks" } | Format-Table Title,Process,PID,Left,Top,Width,Height -AutoSize

Write-Output "---ALL WINDOWS---"
$results | Format-Table Title,Process,PID,Left,Top,Width,Height -AutoSize
