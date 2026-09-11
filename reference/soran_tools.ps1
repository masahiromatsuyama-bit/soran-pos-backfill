Add-Type @"
using System;
using System.Runtime.InteropServices;
public class DpiHelper {
    [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr value);
}
"@ -ErrorAction SilentlyContinue
[DpiHelper]::SetProcessDpiAwarenessContext([IntPtr](-4)) | Out-Null

Add-Type @"
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
    [DllImport("user32.dll")] public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint dwData, UIntPtr dwExtraInfo);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int X, int Y);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int count);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
    public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }

    public static List<IntPtr> GetWindowsForProcess(uint pid) {
        List<IntPtr> result = new List<IntPtr>();
        EnumWindows(delegate(IntPtr hWnd, IntPtr lParam) {
            uint wPid;
            GetWindowThreadProcessId(hWnd, out wPid);
            if (wPid == pid && IsWindowVisible(hWnd)) {
                result.Add(hWnd);
            }
            return true;
        }, IntPtr.Zero);
        return result;
    }

    public static string GetTitle(IntPtr hWnd) {
        StringBuilder sb = new StringBuilder(256);
        GetWindowText(hWnd, sb, 256);
        return sb.ToString();
    }
}
"@ -ErrorAction SilentlyContinue

function Get-AllSoranWindows {
    $procs = Get-Process -Name visual -ErrorAction SilentlyContinue
    $result = @()
    foreach ($p in $procs) {
        $handles = [Win32]::GetWindowsForProcess([uint32]$p.Id)
        foreach ($h in $handles) {
            $title = [Win32]::GetTitle($h)
            if ($title -ne "") {
                $result += [PSCustomObject]@{ ProcessId = $p.Id; Handle = $h; Title = $title }
            }
        }
    }
    return $result
}

function Show-WindowByHandle {
    param([Parameter(Mandatory)][IntPtr]$Handle)
    [Win32]::ShowWindow($Handle, 9) | Out-Null
    [Win32]::SetForegroundWindow($Handle) | Out-Null
    Start-Sleep -Milliseconds (Get-Random -Minimum 250 -Maximum 650)
}

function Get-SoranWindows {
    Get-Process -Name visual -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object Id, MainWindowHandle, MainWindowTitle
}

function Show-SoranWindow {
    param([Parameter(Mandatory)][int]$ProcessId)
    $p = Get-Process -Id $ProcessId
    [Win32]::ShowWindow($p.MainWindowHandle, 9) | Out-Null
    [Win32]::SetForegroundWindow($p.MainWindowHandle) | Out-Null
    Start-Sleep -Milliseconds 300
}

function Get-WinRect {
    param([Parameter(Mandatory)][IntPtr]$Handle)
    $rect = New-Object Win32+RECT
    [Win32]::GetWindowRect($Handle, [ref]$rect) | Out-Null
    return $rect
}

function Take-Screenshot {
    param([Parameter(Mandatory)][string]$Path)
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bmp = New-Object System.Drawing.Bitmap $bounds.Width, $bounds.Height
    $graphics = [System.Drawing.Graphics]::FromImage($bmp)
    $graphics.CopyFromScreen($bounds.Location, [System.Drawing.Point]::Empty, $bounds.Size)
    $bmp.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    $graphics.Dispose(); $bmp.Dispose()
}

function Wait-Random {
    param([int]$MinMs = 250, [int]$MaxMs = 900)
    Start-Sleep -Milliseconds (Get-Random -Minimum $MinMs -Maximum $MaxMs)
}

function Send-ClickAt {
    param([Parameter(Mandatory)][int]$X, [Parameter(Mandatory)][int]$Y)
    # small random overshoot-then-settle so cursor motion isn't perfectly linear/instant
    $jitterX = Get-Random -Minimum -3 -Maximum 4
    $jitterY = Get-Random -Minimum -3 -Maximum 4
    [Win32]::SetCursorPos($X + $jitterX, $Y + $jitterY) | Out-Null
    Start-Sleep -Milliseconds (Get-Random -Minimum 80 -Maximum 220)
    [Win32]::SetCursorPos($X, $Y) | Out-Null
    Start-Sleep -Milliseconds (Get-Random -Minimum 90 -Maximum 260)
    [Win32]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds (Get-Random -Minimum 40 -Maximum 130)
    [Win32]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
    Wait-Random -MinMs 200 -MaxMs 700
}

function Send-DoubleClickAt {
    param([Parameter(Mandatory)][int]$X, [Parameter(Mandatory)][int]$Y)
    Send-ClickAt -X $X -Y $Y
    Start-Sleep -Milliseconds (Get-Random -Minimum 70 -Maximum 160)
    Send-ClickAt -X $X -Y $Y
}

function Send-TextInput {
    param([Parameter(Mandatory)][string]$Text)
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.SendKeys]::SendWait($Text)
}

function Send-KeyInput {
    param([Parameter(Mandatory)][string]$Keys)
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.SendKeys]::SendWait($Keys)
}

Add-Type -AssemblyName UIAutomationClient -ErrorAction SilentlyContinue
Add-Type -AssemblyName UIAutomationTypes -ErrorAction SilentlyContinue

function Get-UIElement {
    param([Parameter(Mandatory)][IntPtr]$Handle)
    return [System.Windows.Automation.AutomationElement]::FromHandle($Handle)
}

function Get-UITree {
    param(
        [Parameter(Mandatory)][IntPtr]$Handle,
        [int]$MaxDepth = 6
    )
    $root = [System.Windows.Automation.AutomationElement]::FromHandle($Handle)
    $results = New-Object System.Collections.Generic.List[object]
    function Walk($el, $depth) {
        if ($depth -gt $MaxDepth -or $null -eq $el) { return }
        try {
            $rect = $el.Current.BoundingRectangle
            $obj = [PSCustomObject]@{
                Depth = $depth
                ControlType = $el.Current.ControlType.ProgrammaticName
                Name = $el.Current.Name
                AutomationId = $el.Current.AutomationId
                X = [int]$rect.X
                Y = [int]$rect.Y
                W = [int]$rect.Width
                H = [int]$rect.Height
            }
            $results.Add($obj) | Out-Null
        } catch {}
        $walker = [System.Windows.Automation.TreeWalker]::RawViewWalker
        $child = $walker.GetFirstChild($el)
        while ($null -ne $child) {
            Walk $child ($depth + 1)
            $child = $walker.GetNextSibling($child)
        }
    }
    Walk $root 0
    return $results
}

function Get-CenterXY {
    param([Parameter(Mandatory)]$Element)
    return @{ X = [int]($Element.X + $Element.W / 2); Y = [int]($Element.Y + $Element.H / 2) }
}
