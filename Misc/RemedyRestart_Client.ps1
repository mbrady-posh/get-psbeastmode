$Choices = @("Y","N")
$Message = "`nAre you sure you want to restart Remedy services?"
$Title = ""
$DefaultChoice = 1
[System.Management.Automation.Host.ChoiceDescription[]]$Poss = $Choices
Foreach ($Possible in $Poss) {            
    New-Object System.Management.Automation.Host.ChoiceDescription "&$($Possible)", "Sets $Possible as an answer." | Out-Null
    }       
$Answer = $Host.UI.PromptForChoice( $Title, $Message, $Poss, $DefaultChoice ) 

If ($Answer -eq "1") {
    Exit 1
    }

Start-Process "schtasks.exe" "/RUN /TN domain\Restart_RemedyServices" | Wait-Process

Write-Progress -Activity "Restarting Remedy services" -Status "This may take more than 5 minutes, please be patient." -PercentComplete 100
Do {
    Start-Sleep -Seconds 5
    }
    Until ( (schtasks.exe /QUERY /TN domain\Restart_RemedyServices /V /FO List | Select-String "Status") -like "*Ready*")
Write-Progress -Activity "Restarting Remedy services" -Status "Processing" -Completed

If ((schtasks.exe /QUERY /TN domain\Restart_RemedyServices /V /FO List | Select-String "Last Result") -notlike "*0*") {
    Write-Error $((Get-EventLog -LogName RemedyRestart -Newest 1).Message)
    "Press any key to exit."
    $key = $host.ui.rawui.ReadKey("NoEcho,IncludeKeyDown")
    }
    Else {
        Write-Output "Restarting remedy services was successful."
        "Press any key to exit."
        $key = $host.ui.rawui.ReadKey("NoEcho,IncludeKeyDown")
        }