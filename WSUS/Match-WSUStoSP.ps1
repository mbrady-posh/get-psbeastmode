$WSUSItems = Invoke-Command -ComputerName "wsus@domain" -UseSSL -ScriptBlock {[reflection.assembly]::LoadWithPartialName("Microsoft.UpdateServices.Administration") | Out-Null

    $WSUSserver = [Microsoft.UpdateServices.Administration.AdminProxy]::GetUpdateServer()

    Function Get-TargetOwner($Target) {
        $TargetGroups = $Target.ComputerTargetGroupIds
        $test = [guid]"guid"
        $PBO = $WSUSserver.GetComputerTargetGroup([guid]"guid").GetChildTargetGroups() | Select Id
        $L4 = $WSUSserver.GetComputerTargetGroup([guid]"guid").GetChildTargetGroups() | Select Id
        $L3 = $WSUSserver.GetComputerTargetGroup([guid]"guid").GetChildTargetGroups() | Select Id
        $Exceptions = $WSUSserver.GetComputerTargetGroup([guid]"guid") | Select Id
        If ($TargetGroups -contains $test) {
            Return "Patched By Owner"
            }
            ElseIf ( $PBO | Foreach-Object { If ( $TargetGroups -contains $_.Id ) { $True } } ) {
                Return "Patched By Owner"
                }
            ElseIf ($L4 | Foreach-Object { If ( $TargetGroups -contains $_.Id ) { $True } } ) {
                $L4 | Foreach-Object { If ( $TargetGroups -contains $_.Id ) { Return $($WSUSserver.GetComputerTargetGroup($_.Id)).Name } }
                }
            ElseIf ($L3 | Foreach-Object { If ( $TargetGroups -contains $_.Id ) { $True } } ) {
               $L3 | Foreach-Object { If ( $TargetGroups -contains $_.Id ) { Return $($WSUSserver.GetComputerTargetGroup($_.Id)).Name } }
               }
            ElseIf ($Exceptions | Foreach-Object { If ( $TargetGroups -contains $_.Id ) { $True } } ) {
               $Exceptions | Foreach-Object { If ( $TargetGroups -contains $_.Id ) { Return $($WSUSserver.GetComputerTargetGroup($_.Id)).Name } }
               }
            Else {
                Return "Other"
                }
        }

    $ComputerScope = New-Object Microsoft.UpdateServices.Administration.ComputerTargetScope
    $ComputerScope.IncludeDownstreamComputerTargets = $True

    $WSUSServer.GetComputerTargets($ComputerScope) | Select FullDomainName,LastSyncTime,@{Name="WSUSGroup";Expression={Get-TargetOwner $($_)}},SPGroup
}

$URI = "http://sharepoint/sites/site/_vti_bin/lists.asmx?WSDL"
$service = New-WebServiceProxy -Uri $uri  -Namespace SpWs  -UseDefaultCredential
$List = "Patching Inventory App Owners and Schedules"
$xmlDoc = new-object System.Xml.XmlDocument
$query = [xml]"<Query />"
$viewFields = [xml]"<ViewFields/>"
$queryOptions = [xml]"<QueryOptions />"
$rowLimit = "1000"

If ($Service -ne $null) {
    $listobj = $service.GetListItems($list, "", $query, $viewFields, $rowLimit, $queryOptions, "")
    }
    Else {
        Write-Error "Service is dead"
        Exit 1
        }
        
$WSUSShortnames = $WSUSItems | Foreach-Object {"$(($_.FullDomainName -split "\.")[0])"}

Foreach ($item in $WSUSItems) {
    Foreach ($spobj in $Listobj.data.row) {
        If ("$(($spobj.ows_Title -split "\.")[0])" -like "$(($item.FullDomainName -split "\.")[0])") {
            $item.SPGroup = $spobj.ows_Future_x0020_Tier_x0020_Grouping
            }
        }
    If ($Item.SPGroup -like "") {
        $item.SPGroup = "System not in patch matrix"
        }
    }

$Differences = Foreach ($item in $WSUSItems) {
    If ($Item.WSUSGroup -ne $item.SPGroup) {
        $item
        }
    }

$NotInWSUS = Foreach ($spobj in $($Listobj.data.row | Where {($_.ows_Future_x0020_Tier_x0020_Grouping -notlike "*LAB Managed*") -and ($_.ows_Title -notlike "*lab.intrado.pri*") })) {
    If ( "$(($spobj.ows_Title -split "\.")[0])" -notin $WSUSShortnames ) {
        $spobj
        }
    }

$Stale = $WSUSItems | Where {$_.LastSyncTime -lt $((Get-Date).AddDays(-7)) }

Foreach ($item in $Stale) { Add-Member -InputObject $item -MemberType NoteProperty -Name "Pingable" -Value $(If (Test-Connection $item.FullDomainName -Count 1 -Quiet) { "Yes" } Else { "No" }) }
Foreach ($item in $NotInWSUS) { Add-Member -InputObject $item -MemberType NoteProperty -Name "Pingable" -Value $(If (Test-Connection $item.ows_Title -Count 1 -Quiet) { "Yes" } Else { "No" }) }

$EmailBody = "<style>td { padding-left: 5px; padding-right: 5px }</style><h3>WSUS and patch matrix mismatches</h3><table style=`"background:#A7BFDE;border: 1px solid white;color:black;border-collapse:collapse;font-family:calibri;`"><tr style=`"background:#4F81BD;color:white`"><td style=`"border: 1px solid white;border-bottom: 2px`">Name</td><td style=`"border: 1px solid white;border-bottom: 2px`">WSUS Group</td><td style=`"border: 1px solid white;border-bottom: 2px`">SP Group</td></tr>"
Foreach ($Difference in $Differences) {
    $EmailBody = "$($EmailBody)<tr><td style=`"border: 1px solid white`">$($Difference.FullDomainName)</td><td style=`"border: 1px solid white`">$($Difference.WSUSGroup)</td><td style=`"border: 1px solid white`">$($Difference.SPGroup)</td></tr>"
    }
$EmailBody = "$($EmailBody)</table>"

$EmailBody = "$($EmailBody)<style>td { padding-left: 5px; padding-right: 5px }</style><h3>Stale WSUS objects</h3><table style=`"background:#A7BFDE;border: 1px solid white;color:black;border-collapse:collapse;font-family:calibri;`"><tr style=`"background:#4F81BD;color:white`"><td style=`"border: 1px solid white;border-bottom: 2px`">Name</td><td style=`"border: 1px solid white;border-bottom: 2px`">Pingable</td></tr>"
Foreach ($StaleItem in $Stale) {
    $EmailBody =  "$($EmailBody)<tr><td style=`"border: 1px solid white`">$($StaleItem.FullDomainName)</td><td style=`"border: 1px solid white`">$($StaleItem.Pingable)</td></tr>"
    }
$EmailBody = "$($EmailBody)</table>"

$EmailBody = "$($EmailBody)<style>td { padding-left: 5px; padding-right: 5px }</style><h3>Missing from WSUS</h3><table style=`"background:#A7BFDE;border: 1px solid white;color:black;border-collapse:collapse;font-family:calibri;`"><tr style=`"background:#4F81BD;color:white`"><td style=`"border: 1px solid white;border-bottom: 2px`">Name</td><td style=`"border: 1px solid white;border-bottom: 2px`">Pingable</td><td style=`"border: 1px solid white;border-bottom: 2px`">SP Group</td></tr>"
Foreach ($Missing in $NotInWSUS) {
    $EmailBody = "$($EmailBody)<tr><td style=`"border: 1px solid white`">$($Missing.ows_Title)</td><td style=`"border: 1px solid white`">$($Missing.Pingable)</td><td style=`"border: 1px solid white`">$($Missing.ows_Future_x0020_Tier_x0020_Grouping)</td></tr>"
    }
$EmailBody = "$($EmailBody)</table>"

Send-MailMessage -To to@domain -From "wsus@domain" -Subject "WSUS Systems Report" -BodyAsHtml $EmailBody -SmtpServer $smtpserver