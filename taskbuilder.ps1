# Prompt user for script file name
try{
    do {    
        $scriptfileName = Read-Host "Select a script 'name.ps1'"
        $scriptPath = "C:\666test\$scriptfileName"
    
        if(-not (Test-Path $scriptPath)){
            Write-Host "File '$scriptfileName' does not exist, please enter a valid file name."    
            $scriptSelected = $false
        } else {
            Write-Host "File '$scriptfileName' selected."
            $scriptSelected = $true
        }
    } while (-not $scriptSelected)
}
catch{
    Write-Host $($_.Exception.message)
}

# Create log path and file
$desiredPart = $scriptfileName -split '-\d{8}\.ps1$' | Select-Object -First 1
$logFilePath = "C:\dump\log\$desiredPart-$(Get-Date -Format 'yyyy-MM-dd')-log.txt"
New-Item -ItemType File -Path $logFilePath -Force

# Define log function
function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Message,
 
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('Info','Debug','Warning','Error')]
        [string]$Severity = 'Info'
    )
    $logEntry = "{0} [{1}] {2}" -f (Get-Date -f g), $Severity, $Message
    Add-Content -Path $logFilePath -Value $logEntry
}

try{
    if (-not (Test-Path $logFilePath)) {
        New-Item -ItemType File -Path $logFilePath -Force
        Write-Log -Message Log file "$scriptfileName  rebuild." -Severity Debug
    } else {
        Write-Log -Message "Log file'$scriptfileName' build up success." -Severity Debug
    }
}
catch {
    Write-Host $($_.Exception.message)
    Write-Log -Message $($_.Exception.message) -Severity Error
}

# Excute task scheduler set
try{
    # Create a new action
    $taskAction = New-ScheduledTaskAction `
    -Execute 'powershell.exe' `
    -Argument "-NoExit -ExecutionPolicy Bypass -File `"$scriptPath`""

    # Create a new trigger
    do{
	    $timeset = Read-Host "Set a trigger time(e.g. 09:16AM or 06:18PM)"
	    if (-not [regex]::IsMatch($timeset, '^((0?[1-9]|1[0-2]):([0-5][0-9])(am|pm|AM|PM))$')) {
		    Write-Host "Invalid input format. Please enter the corrcect time format 'HH:MMAM/PM'."
	    }
    } While (-not [regex]::IsMatch($timeset, '^((0?[1-9]|1[0-2]):([0-5][0-9])(am|pm|AM|PM))$'))
    $taskTrigger = New-ScheduledTaskTrigger -Daily -At $timeset

    # Create a battery set
    $powerStatus = Get-WmiObject -Class Win32_Battery
    if ($powerStatus.BatteryStatus -eq 1) { # Battery Power
        Write-Log -Message "Power status: Using Battery" -Severity Debug
    } else { # AC Power
        Write-Log -Message "Power status: Plugged In" -Severity Debug
    }

    # Create a new scheduled task set
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries:$true `
    -DontStopIfGoingOnBatteries:$true `
    -RestartCount:3 `
    -RestartInterval (New-TimeSpan -Minutes 1) `
    -StartWhenAvailable:$true
}
catch{
    Write-Host $($_.Exception.message)
    Write-Log -Message $($_.Exception.message) -Severity Error
}

# Set task name
$taskName = Read-Host "Create a task name: "
$description = Read-Host "Make a description for new scheduled task: "
if([string]::IsNullOrEmpty($description)){
	$description = "None"
}

# Check if the task name already exists
$existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($null -ne $existingTask) {
    Write-Host "Task name '$taskName' already exists."
  do{
        $repeatRegister = Read-Host "Choose Y to overwrite or N to rebuild a new scheduledTask name: (y/n)"

        # Overwrite a task
        if ($repeatRegister.ToLower() -eq "y") {
            Register-ScheduledTask -TaskName $taskName `
                                   -Action $taskAction `
                                   -Trigger $taskTrigger `
                                   -Settings $settings `
                                   -Description $description `
                                   -Force
            Write-Host "Task '$taskName' overwrite successfully."

            # Log success to a text file
            Write-Log -Message "Task '$taskName' overwrite successfully." -Severity Info
            Exit
        }
        # Build a new task
        elseif($repeatRegister.ToLower() -eq "n") {
                $newtaskName = Read-Host "Create a new task name: "
                $newdescription = Read-Host "Make a description for new scheduled task: "
                if([string]::IsNullOrEmpty($newdescription)){
                    $newdescription = "None"
                }
                Register-ScheduledTask -TaskName $newtaskName `
                                       -Action $taskAction `
                                       -Trigger $taskTrigger `
                                       -Settings $settings `
                                       -Description $newdescription
                                       Write-Log -Message "Task '$newtaskName' register successfully." -Severity Debug
        }
        else{
            Write-Host "Invalid input. Please enter Y to overwrite or N to rebuild a new scheduledTask name."
        }
    } while (($repeatRegister.ToLower() -ne "y") -and ($repeatRegister.ToLower() -ne "n"))
}
else{
        try{
            # Register the scheduled task
            Register-ScheduledTask -TaskName $taskName `
                                   -Action $taskAction `
                                   -Trigger $taskTrigger `
                                   -Settings $settings `
                                   -Description $description
            
            # Log success to a text file
            Write-Log -Message "Task '$taskName' register successfully." -Severity Debug
        }
        catch{
        # Log the error message
        Write-Log -Message "Task:'$taskname': $($_.Exception.Message)" -Severity Error
        Write-Host $($_.Exception.message)
    }
}
# Delay for seconds
#Start-Sleep -Seconds 1

# Shutdown PowerShell
#$host.SetShouldExit(0)