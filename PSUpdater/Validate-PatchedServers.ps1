Param(
    [Parameter(Mandatory=$True)][string]$hostname,
    [Parameter(Mandatory=$True)]$ZoneCreds,
    [Parameter(Mandatory=$True)][datetime]$Reboottime
    )

    Function Select-Credentials($HostName) {
                If ($(($Hostname.Split("."))[1]) -like "domain1") {
                    Get-Credential $($ZoneCreds.domain)
                    }
                    ElseIf ($(($Hostname.Split("."))[1]) -like "domain3") {
                        Get-Credential $($ZoneCreds.domain)
                        }
                    Else {
                        Get-Credential $($ZoneCreds.$($Hostname.Split(".")[1]))
                        }
                }

    $script:scriptpath = split-path -parent $MyInvocation.MyCommand.Definition

    $BadServices = Invoke-command -ComputerName $Hostname -Credential  (Select-Credentials $Hostname) -ScriptBlock {Get-WmiObject -Class Win32_Service | Where {(($_.StartMode -eq "Automatic") -and ($_.State -ne "Started"))} }
    
    $BadLogs = @()
    $BadLogs += Invoke-command -ComputerName $Hostname -Credential  (Select-Credentials $Hostname) -ScriptBlock {Get-EventLog -LogName Application -After $Reboottime -EntryType Error}
    $BadLogs += Invoke-command -ComputerName $Hostname -Credential  (Select-Credentials $Hostname) -ScriptBlock {Get-EventLog -LogName System -After $Reboottime -EntryType Error}

    If (Test-Path "$($script:scriptpath)\$($Hostname)_validate.csv") {
        $ExtraValidation = New-Object PSCustomObject
        $Validationcsv = Import-Csv "$($script:scriptpath)\$($Hostname)_validate.csv"
        Foreach ($item in $Extravalidation) {
            Add-Member -InputObject $ExtraValidation -MemberType NoteProperty -Name $($item.Name) -Value $($item.Command)
            }
         }

    If ($ExtraValidation) {
        Foreach ($val in $ExtraValidation) {
            Invoke-Expression $val.Command
            }
        }