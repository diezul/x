# ===============================
# PawnshopLock – Smart Installer
# ===============================
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ---- CONFIG -----------------------------------------------------------
$repoRaw  = 'https://raw.githubusercontent.com/diezul/x/main' # GitHub RAW root
$mainFile = 'pawnlock.ps1'                                   # main service script
$localDir = "$env:ProgramData\PawnshopLock"                  # local safe folder
$taskName = 'PawnshopLockService'                            # scheduled task name
# ----------------------------------------------------------------------

# ---- helper: are we admin? -------------------------------------------
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$IsAdmin   = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# ---- 1. grab latest service script -----------------------------------
New-Item -ItemType Directory -Path $localDir -Force | Out-Null
Invoke-WebRequest "$repoRaw/$mainFile" -OutFile "$localDir\$mainFile" -UseBasicParsing

# ---- 2. build task action --------------------------------------------
$action  = New-ScheduledTaskAction `
           -Execute 'powershell.exe' `
           -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$localDir\$mainFile`""

# trigger: run on every user log‑on (works for normal & admin accounts)
$trigger = New-ScheduledTaskTrigger -AtLogOn

# ---- 3. register task -------------------------------------------------
try {
    if ($IsAdmin) {
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger `
                               -RunLevel Highest -Force | Out-Null
    } else {
        # no admin: register under current user (no RunLevel switch)
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Force | Out-Null
    }
}
catch {
    Write-Warning "Could not register scheduled task: $_"
    Write-Host "Try running this installer from an **Administrator** PowerShell." -ForegroundColor Yellow
    exit
}

# ---- 4. launch immediately in background -----------------------------
Start-Process powershell -WindowStyle Hidden `
    -ArgumentList "-ExecutionPolicy Bypass -File `"$localDir\$mainFile`""
