# Set the path and directory of MySQL'S bin
$env:Path += ";C:\Program Files\MySQL\MySQL Server 8.0\bin"

# Set logging
$mysqlUser = "root"
$mysqlPassword = "1234"

# Catch and splitting the file name
$scriptfileName = $MyInvocation.MyCommand.Name
$desiredPart = $scriptfileName -split '-\d{8}\.ps1$' | Select-Object -First 1

Write-Host "Script file name: $scriptfileName"
# Get current date and time in YYYY-MM format
$currentDate = Get-Date -Format "yyyy-MM"

# Set the output directory and file name
$outputDirectory = "C:\dump\$currentdate"
$outputFile = Join-Path -Path $outputDirectory -ChildPath "$desiredPart-$(Get-Date -Format 'yyyy-MM-dd').sql"

# Create the output directory if it doesn't exist
if (-not (Test-Path $outputDirectory)) {
    New-Item -ItemType Directory -Path $outputDirectory | Out-Null
}

# Create log path and file
$logFilePath = "C:\dump\log\$desiredPart-$(Get-Date -Format 'yyyy-MM-dd')-log.txt"

if (-not (Test-Path $logFilePath)) {
    New-Item -ItemType File -Path $logFilePath -Force
}

# Defint log function
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

# Create a battery task Set
$battery = Get-WmiObject -Class Win32_Battery
if ($battery.BatteryStatus -eq 1) { # Battery Power
    Write-Log -Message "Schema back up, Power status: Using Battery" -Severity Debug
} 
else { # AC Power
    Write-Log -Message "Schema back up, Power status: Plugged In" -Severity Debug
}

# Execute mysqldump command to back up
try {
    $processStartInfo = New-Object System.Diagnostics.ProcessStartInfo
    $processStartInfo.FileName = 'mysqldump'
    $processStartInfo.Arguments = "--user=$mysqlUser --password=$mysqlPassword micron_mcs -r $outputfile"
    $processStartInfo.RedirectStandardOutput = $true
    $processStartInfo.RedirectStandardError = $true # 將錯誤訊息送至標準輸出流
    $processStartInfo.UseShellExecute = $false

    $process = [System.Diagnostics.Process]::Start($processStartInfo)

    $process.WaitForExit()

    if ($process.ExitCode -eq 0) {
        Write-Host "Schema name '$desiredPart' Back up successfully!"
        # Log success to a text file
        Write-Log -Message "Schema name '$desiredPart' back up successfully" -Severity Debug
    }
    else {
        #$errorMessage = "Error: mysqldump failed with exit code $($process.ExitCode)"
        $errorMessage = "Exit code = $($process.ExitCode)"
        throw $errorMessage
    }
}
catch
{
    $errorMessage = "$($_.Exception.Message)"    
    # Log error to a text file
    $errorOutput = $process.StandardError.ReadToEnd()  # 獲取錯誤訊息
    Write-Host "Error: $errorMessage, $errorOutput"
    Write-Log -Message "Schema name '$desiredPart', $errorMessage, $errorOutput" -Severity Error  # 將錯誤訊息寫入log檔中
    
    $process.Dispose()
}

# Delay for seconds
Start-Sleep -Seconds 1 

# Shutdown PowerShell
$host.SetShouldExit(0)