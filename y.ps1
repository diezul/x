# URL-ul imaginii de afișat
$imageURL = "https://is.gd/specificatii-laptop.jpg"
$tempImagePath = "$env:TEMP\imagine.jpg"

# Descărcarea imaginii
try {
    Invoke-WebRequest -Uri $imageURL -OutFile $tempImagePath -ErrorAction Stop
} catch {
    Write-Host "Eroare la descărcarea imaginii. Verificați conexiunea la internet." -ForegroundColor Red
    exit
}

# Afișarea imaginii pe ecran complet
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form = New-Object System.Windows.Forms.Form
$form.WindowState = 'Maximized'
$form.FormBorderStyle = 'None'
$form.TopMost = $true
$form.BackColor = [System.Drawing.Color]::Black
$form.WindowState = [System.Windows.Forms.FormWindowState]::Maximized
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
$form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
$form.KeyPreview = $true

$pictureBox = New-Object System.Windows.Forms.PictureBox
$pictureBox.Image = [System.Drawing.Image]::FromFile($tempImagePath)
$pictureBox.Dock = 'Fill'
$pictureBox.SizeMode = 'StretchImage'
$form.Controls.Add($pictureBox)

# Dezactivarea combinațiilor de taste Alt+Tab, Ctrl+Alt+Delete, etc.
$null = [System.Runtime.InteropServices.Marshal]::Prelink([System.Windows.Forms.Application]::typeid.GetMethod("EnableVisualStyles"))

# Monitorizarea tastelor apăsate
$form.Add_KeyDown({
    param($sender, $e)
    if ($e.KeyCode -eq [System.Windows.Forms.Keys]::C -and $e.Modifiers -eq [System.Windows.Forms.Keys]::Control) {
        $global:exitFlag = $true
        $form.Close()
    }
})

$form.Add_FormClosing({
    if (-not $global:exitFlag) {
        $form.Show()
        [System.Windows.Forms.Application]::DoEvents()
    }
})

[void]$form.ShowDialog()
