[CmdletBinding()]
param (
    [ValidateNotNullOrEmpty()]
    [string[]]
    $ServiceDisplayName = @(
        'PaperCut Direct Print Monitor'
        'PaperCut Print Deploy Client'
    ),

    [ValidateNotNullOrEmpty()]
    [string]
    $LogDirectory = 'C:\Logs\PDQDeploy\Validate-PDServiceRunning',

    [ValidateNotNullOrEmpty()]
    [string[]]
    $To = 'My Name <my.email@domain.com>',

    [ValidateNotNullOrEmpty()]
    [string]
    $From = 'Some Name <some.email@domain.com>'
)

$ErrorActionPreference = 'Stop'
$MaxTimeout = New-TimeSpan -Seconds 241
$Log = ''
$TranscriptFile = "$LogDirectory\Validate-PDServiceRunning.log"
if (-not (Test-Path $LogDirectory)) {
    New-Item -ItemType Directory -Path $LogDirectory -Force -ErrorAction Stop | Out-Null
}

foreach ($IndividualServiceDisplayName in $ServiceDisplayName) {
    try {
        $SendEmail = $false
        $Service = Get-Service -DisplayName $IndividualServiceDisplayName
        if ($Service) {
            $Status = $Service.Status
            $StartType = $Service.StartType
            $Time = $(Get-Date -Format "yyyy/MM/dd HH:mm")
            $Log = "$Time : $IndividualServiceDisplayName status is currently $Status"
            $Log += "`r`n`tStart type is currently $StartType"
            $Log += "`r`n`tComputer Name is $($env:COMPUTERNAME)"
            $LastRestart = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime.ToString("yyyy/MM/dd HH:mm")
            $Log += "`r`n`tLast restart was: $lastRestart"
            if ($StartType -notin @('Automatic', 'Boot', 'System')) {
                $Log += "`r`n`tAttempting to set service start type to Automatic"
                Set-Service -Name $Service.Name -StartupType 'Automatic'
                $Log += "`r`n`tService start type set to Automatic successfully"
            }
            if ($Status -ne 'Running') {
                $SendEmail = $true
                switch ($Status) {
                    'Stopped' {
                        $Log += "`r`n`tAttempting to start service"
                        Start-Service -DisplayName $IndividualServiceDisplayName
                        $Log += "`r`n`tWaiting for service to start"
                        $Service.WaitForStatus('Running', $MaxTimeout)
                        $Log += "`r`n`tService started successfully"
                    }
                    'StartPending' {
                        $Log += "`r`n`tWaiting for service to start"
                        $Service.WaitForStatus('Running', $MaxTimeout)
                        $Log += "`r`n`tService started successfully"
                    }
                    'ContinuePending' {
                        $Log += "`r`n`tWaiting for service to continue"
                        $Service.WaitForStatus('Running', $MaxTimeout)
                        $Log += "`r`n`tService continued successfully"
                    }
                    'StopPending' {
                        $Log += "`r`n`tWaiting for service to stop"
                        $Service.WaitForStatus('Stopped', $MaxTimeout)
                        $Log += "`r`n`tService is stopped; waiting 15 seconds in case service restarts from something else"
                        $ContinueLoop = $true
                        $Loops = 0
                        while ($ContinueLoop -and ($Loops -le 20)) {
                            $Loops ++
                            Start-Sleep -Seconds 15
                            $Service = Get-Service -DisplayName $IndividualServiceDisplayName
                            if ($Service) {
                                if ($Service.Status -eq 'Stopped') {
                                    $Log += "`r`n`tAttempting to start service"
                                    Start-Service -DisplayName $IndividualServiceDisplayName
                                    $Log += "`r`n`tWaiting for service to start"
                                    $Service.WaitForStatus('Running', $MaxTimeout)
                                    $Log += "`r`n`tService started successfully"
                                    $ContinueLoop = $false
                                }
                                elseif ($Service.Status -eq 'StartPending') {
                                    $Log += "`r`n`tStartPending; waiting 15 seconds"
                                }
                                elseif ($Service.Status -eq 'Running') {
                                    $Log += "`r`n`tService started"
                                    $ContinueLoop = $false
                                }
                                else {
                                    $Log += "`r`n`t$($Service.Status); don't know why this would ever happen, but here we are"
                                    $ContinueLoop = $false
                                }
                            }
                            else {
                                $Log += "`r`n`t$IndividualServiceDisplayName Service Does Not Exist"
                            }
                        }
                        if ($Loops -ge 21) {
                            $Log += "`r`n`tService got stuck in a loop"
                        }
                    }
                    'Paused' {
                        $Log += "`r`n`tAttempting to resume service"
                        Resume-Service -DisplayName $IndividualServiceDisplayName
                        $Log += "`r`n`tWaiting for service to resume"
                        $Service.WaitForStatus('Running', $MaxTimeout)
                        $Log += "`r`n`tService resumed successfully"
                    }
                    'PausePending' {
                        $Log += "`r`n`tWaiting for service to pause"
                        $Service.WaitForStatus('Paused', $MaxTimeout)
                        $Log += "`r`n`tAttempting to resume service"
                        Resume-Service -DisplayName $IndividualServiceDisplayName
                        $Log += "`r`n`tWaiting for service to resume"
                        $Service.WaitForStatus('Running', $MaxTimeout)
                        $Log += "`r`n`tService resumed successfully"
                    }
                    default {
                        $Log += "`r`n`tService status $Status is not a valid service status"
                    }
                }
            }
        }
        else {
            $SendEmail = $true
            $Time = $(Get-Date -Format "yyyy/MM/dd HH:mm")
            $Log = "$Time : $IndividualServiceDisplayName does not exist"
            $Log += "`r`n`tComputer Name is $($env:COMPUTERNAME)"
            $LastRestart = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime.ToString("yyyy/MM/dd HH:mm")
            $Log += "`r`n`tLast restart was: $lastRestart"
        }
        $ErrorEncountered = $false
    }
    catch {
        $Log += "`r`n`tERROR while running $($MyInvocation.MyCommand):"
        $Log += "`r`n`t   $($_ | Out-String)"
        $ErrorEncountered = $true
        $SendEmail = $true
    }
    finally {
        Write-Host $Log
        if ($SendEmail) {
            $EmailParam = @{
                'Subject'    = "$($env:COMPUTERNAME): $IndividualServiceDisplayName was $Status and $StartType"
                'To'         = $To
                'From'       = $From
                'SmtpServer' = 'smtp.mydomain.com'
                'Body'       = $Log
                'UseSSL'     = $true
                'Port'       = 587
            }
            if ($ErrorEncountered) {
                $EmailParam['Subject'] = "$($env:COMPUTERNAME): ERROR Encountered While Validating Service $IndividualServiceDisplayName"
            }
            else {
                $EmailParam['Subject'] = "$($env:COMPUTERNAME): $IndividualServiceDisplayName was $Status and $StartType"
            }
            Send-MailMessage @EmailParam
        }
        Add-Content -Path $TranscriptFile -Value $Log
    }
}
