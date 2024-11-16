# Configurații
$imageURL = "https://is.gd/specificatii-laptop.jpg"
$tempImagePath = "$env:TEMP\specificatii-laptop.jpg"
$adminPassword = "12345"  # Parola de administrator pentru închiderea programului

# Descărcarea imaginii
Invoke-WebRequest -Uri $imageURL -OutFile $tempImagePath

# Funcție pentru afișarea imaginii pe tot ecranul
function Show-FullScreenImage {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form = New-Object System.Windows.Forms.Form
    $form.WindowState = 'Maximized'
    $form.FormBorderStyle = 'None'
    $form.TopMost = $true
    $form.KeyPreview = $true

    $img = [System.Drawing.Image]::FromFile($tempImagePath)
    $pictureBox = New-Object System.Windows.Forms.PictureBox
    $pictureBox.Image = $img
    $pictureBox.Dock = 'Fill'
    $pictureBox.SizeMode = 'StretchImage'
    $form.Controls.Add($pictureBox)

    $global:exitFlag = $false
    $form.Add_KeyDown({
        param($sender, $eventArgs)
        $global:keySequence += $eventArgs.KeyCode.ToString()
        if ($global:keySequence -like "*C*D*R") {
            $password = Read-Host "Introduceți parola pentru închidere"
            if ($password -eq $adminPassword) {
                $global:exitFlag = $true
                $form.Close()
            } else {
                Write-Host "Parolă incorectă!"
                $global:keySequence = ""
            }
        }
    })

    while (-not $global:exitFlag) {
        Start-Sleep -Milliseconds 100
    }

    $form.Close()
}

# Funcție pentru a verifica procesul
function Monitor-Process {
    while ($true) {
        if (-not (Get-Process -Id $pid -ErrorAction SilentlyContinue)) {
            Start-Process powershell -ArgumentList "-File `"$MyInvocation.MyCommand.Path`""
            exit
        }
        Start-Sleep -Seconds 1
    }
}

# Funcție pentru setarea persistenței
function Set-Startup {
    $scriptPath = $MyInvocation.MyCommand.Path
    $taskName = "PersistentImageViewer"

    # Adaugă o sarcină în Task Scheduler
    schtasks /create /tn $taskName /tr "powershell.exe -File '$scriptPath'" /sc onlogon /rl highest /f
}

# Activarea persistenței
Set-Startup

# Lansare monitorizare secundară
Start-Job -ScriptBlock { Monitor-Process }

# Afișarea imaginii
Show-FullScreenImage

# Curățare după dezactivare completă
if ($global:exitFlag) {
    schtasks /delete /tn "PersistentImageViewer" /f
    Write-Host "Aplicația a fost dezactivată complet."
}
