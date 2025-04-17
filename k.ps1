# ==========================
# PawnshopLock  –  Installer
# ==========================

# --- CONFIGURE ----------------------------------------------------------
$repoRaw  = 'https://raw.githubusercontent.com/diezul/x/main'   # your repo root
$mainFile = 'pawnlock.ps1'                                      # main script name
$localDir = "$env:ProgramData\PawnshopLock"                     # safe local storage
$taskName = 'PawnshopLockService'                               # scheduled‑task name
# -----------------------------------------------------------------------

# Ensure local folder exists + latest script downloaded
New-Item -ItemType Directory -Path $localDir -Force | Out-Null
Invoke-WebRequest "$repoRaw/$mainFile" -OutFile "$localDir\$mainFile" -UseBasicParsing

# Build scheduled–task action (hidden, bypass policy)
$action  = New-ScheduledTaskAction `
           -Execute 'powershell.exe' `
           -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$localDir\$mainFile`""

# Trigger at **every log‑on** (you can switch to –AtStartup and RunAs SYSTEM if preferred)
$trigger = New-ScheduledTaskTrigger -AtLogOn

# Register or replace the task – run with highest privileges so a normal user can’t kill it
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -RunLevel Highest -Force

# Launch immediately for this session
Start-Process powershell -WindowStyle Hidden -ArgumentList "-ExecutionPolicy Bypass -File `"$localDir\$mainFile`""
