<#
.SYNOPSIS
    Creates a scheduled task to enable folder redirection at user login.
    Enable folder redirection on Windows 10 Azure AD joined PCs.
    Downloads the folder redirection script from a URL locally and creates the schedule task.
#>

# Variables
$Url = "https://raw.githubusercontent.com/aaronparker/intune/master/Folder-Redirection/Redirect-Folders.ps1"
$Target = "$env:ProgramData\Scripts"
$Script = "Redirect-Folders.ps1"
$TaskName = "Folder Redirection"
$Group = "BUILTIN\Users"
$Execute = "powershell.exe"
$Arguments = "-ExecutionPolicy Bypass -NonInteractive -WindowStyle Minimized -File $Target\$Script"

Start-Transcript -Path "$Target\$($MyInvocation.MyCommand.Name).log"

# If local path for script doesn't exist, create it
If (!(Test-Path $Target)) { New-Item -Path $Target -Type Directory -Force }

# Download the script from the source repository
If (Test-Path "$Target\$Script") { Remove-Item -Path "$Target\$Script" -Force }
Start-BitsTransfer -Source $Url -Destination "$Target\$Script" -Priority Foreground -Verbose -ErrorAction SilentlyContinue -ErrorVariable $TransferError

# Get an existing local task if it exists
If ($Task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) { 

    # If the task Action differs from what we have above, update the values and save the task
    If (!( ($Task.Actions[0].Execute -eq $Execute) -and ($Task.Actions[0].Arguments -eq $Arguments) )) {
        $Task.Actions[0].Execute = $Execute
        $Task.Actions[0].Arguments = $Arguments
        $Task | Set-ScheduledTask
    }

} Else {
    
    # Build a new task object
    $action = New-ScheduledTaskAction -Execute $Execute -Argument $Arguments
    $trigger =  New-ScheduledTaskTrigger -AtLogon -RandomDelay (New-TimeSpan -Minutes 1)
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -Hidden -DontStopIfGoingOnBatteries -Compatibility Win8
    $principal = New-ScheduledTaskPrincipal -GroupId $Group
    $newTask = New-ScheduledTask -Action $action -Trigger $trigger -Settings $settings -Principal $principal

    # No task object exists, so register the new task
    Register-ScheduledTask -InputObject $newTask -TaskName $TaskName
}

Stop-Transcript
