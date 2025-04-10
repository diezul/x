Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName PresentationFramework

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class InputBlocker {
    [DllImport("user32.dll")]
    public static extern bool BlockInput(bool fBlockIt);
}
"@

# Salvează poza local
$tempImage = "$env:TEMP\poza_laptop.jpg"
Invoke-WebRequest -Uri "https://github.com/diezul/x/blob/main/1.jpg?raw=true" -OutFile $tempImage

# Blochează input-ul
[InputBlocker]::BlockInput($true)

# Creează formularul
$form = New-Object Windows.Forms.Form
$form.WindowState = 'Maximized'
$form.FormBorderStyle = 'None'
$form.TopMost = $true
$form.BackColor = 'Black'
$form.StartPosition = 'CenterScreen'
$form.KeyPreview = $true
$form.Cursor = [System.Windows.Forms.Cursors]::None

# Încarcă imaginea
$pictureBox = New-Object Windows.Forms.PictureBox
$pictureBox.ImageLocation = $tempImage
$pictureBox.SizeMode = 'Zoom'
$pictureBox.Dock = 'Fill'
$form.Controls.Add($pictureBox)

# Eveniment apăsare tastă
$form.Add_KeyDown({
    if ($_.KeyCode -eq 'C') {
        [InputBlocker]::BlockInput($false)
        $form.Close()
    }
})

# Rulează formularul (poza full screen)
[void]$form.ShowDialog()
