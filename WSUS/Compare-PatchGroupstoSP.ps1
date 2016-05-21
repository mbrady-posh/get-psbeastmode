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

$SPobjs = Foreach ($item in $listobj.data.row) {
    New-Object PSCustomObject -Property @{"Name"=$($item.ows_Title);"OwnerList"=$($item.ows_App_x0020_Owner);"PatchSchedule"=$item.ows_Future_x0020_Tier_x0020_Grouping}
    }

$Errors = @()

Try {
    $PatchGroups = get-adgroup -filter * -SearchBase "OU=Patch Groups,OU=Groups,DC=domain,DC=com"
    }
    Catch {
        $Errors += $error[0]
        }

[array]$ChangeArray = Foreach ($PatchGroup in $PatchGroups) {
    $Changes = $null
    $Changes = New-Object PSCustomObject -Property @{"$($PatchGroup.Name)"=$(New-Object PSCustomObject)}
   Add-Member -MemberType NoteProperty -InputObject $Changes.$($PatchGroup.Name) -Name "Additions" -Value @()
   Add-Member -MemberType NoteProperty -InputObject $Changes.$($PatchGroup.Name) -Name "Removals" -Value @()
    Switch (($PatchGroup -split "-")[1]) {
        "First" { $SPMembers = $null; $Members = $null ; $Members = (Get-ADGroupMember $PatchGroup).Name ; $SPMembers = $SPObjs | Where {$_.PatchSchedule -like "1st $(($PatchGroup.Name -split "-")[2])"} | 
            Foreach-Object { ($_.OwnerList -split ";").Trim().ToLower() } | Select -Unique ; Compare-Object $Members $SPMembers | Foreach-Object { If ($_.SideIndicator -eq "=>") { $Changes.$($PatchGroup.Name).Additions += $_.InputObject } Else { $Changes.$($PatchGroup.Name).Removals += $_.InputObject } } }
        "Second" { $SPMembers = $null; $Members = $null ; $Members = (Get-ADGroupMember $PatchGroup).Name ; $SPMembers = $SPObjs | Where {$_.PatchSchedule -like "2nd $(($PatchGroup.Name -split "-")[2])"} | 
            Foreach-Object { ($_.OwnerList -split ";").Trim().ToLower() } | Select -Unique ; Compare-Object $Members $SPMembers | Foreach-Object { If ($_.SideIndicator -eq "=>") { $Changes.$($PatchGroup.Name).Additions += $_.InputObject } Else { $Changes.$($PatchGroup.Name).Removals += $_.InputObject } } }
        "Third" { $SPMembers = $null; $Members = $null ; $Members = (Get-ADGroupMember $PatchGroup).Name ; $SPMembers = $SPObjs | Where {$_.PatchSchedule -like "3rd $(($PatchGroup.Name -split "-")[2])"} | 
            Foreach-Object { ($_.OwnerList -split ";").Trim().ToLower() } | Select -Unique ; Compare-Object $Members $SPMembers | Foreach-Object { If ($_.SideIndicator -eq "=>") { $Changes.$($PatchGroup.Name).Additions += $_.InputObject } Else { $Changes.$($PatchGroup.Name).Removals += $_.InputObject } } }
        "Fourth" { $SPMembers = $null; $Members = $null ; $Members = (Get-ADGroupMember $PatchGroup).Name ; $SPMembers = $SPObjs | Where {$_.PatchSchedule -like "4th $(($PatchGroup.Name -split "-")[2])"} | 
            Foreach-Object { ($_.OwnerList -split ";").Trim().ToLower() } | Select -Unique ; Compare-Object $Members $SPMembers | Foreach-Object { If ($_.SideIndicator -eq "=>") { $Changes.$($PatchGroup.Name).Additions += $_.InputObject } Else { $Changes.$($PatchGroup.Name).Removals += $_.InputObject } } }
        }
    $Changes
    }

Foreach ($GroupChange in $ChangeArray) {
    Foreach ($item in $GroupChange.$(($GroupChange | Get-Member | Where {$_.MemberType -eq "NoteProperty"}).Name).Additions) {
        Try {
            $ErrorActionPreference = "Stop"
            Add-ADGroupMember -Identity ($GroupChange | Get-Member | Where {$_.MemberType -eq "NoteProperty"}).Name -Members $(Get-ADObject -Filter {(Name -eq $item) -and ((objectclass -eq "user") -or (objectclass -eq "group"))}) -Confirm:$False
            }
            Catch {
                $Errors += $error[0]
                }
            Finally {
                $ErrorActionPreference = "Continue"
                }
        }
    Foreach ($item in $GroupChange.$(($GroupChange | Get-Member | Where {$_.MemberType -eq "NoteProperty"}).Name).Removals) {
        Try {
            $ErrorActionPreference = "Stop"
            Remove-ADGroupMember -Identity ($GroupChange | Get-Member | Where {$_.MemberType -eq "NoteProperty"}).Name -Members $(Get-ADObject -Filter {(Name -eq $item) -and ((objectclass -eq "user") -or (objectclass -eq "group"))}) -Confirm:$False
            }
            Catch {
                $Errors += $error[0]
                }
            Finally {
                $ErrorActionPreference = "Continue"
                }
        }
    }

If ($Errors.Count -gt 0) {
    $EmailBody = "<p><h3>Patch Matrix / Patch Notification Group Sync Results</h3></p><p><h4>Errors</h4>"
    Foreach ($errorobj in $Errors) {
        $EmailBody = "$($EmailBody)<p style=`"color:red`">$($Errorobj)</p>"
        }
    }

Foreach ($GroupChange in $ChangeArray) {
        If (($GroupChange.$(($GroupChange | Get-Member | Where {$_.MemberType -eq "NoteProperty"}).Name).Additions.Count -ne 0) -or ($GroupChange.$(($GroupChange | Get-Member | Where {$_.MemberType -eq "NoteProperty"}).Name).Removals.Count -ne 0)) {
            If (!($EmailBody)) {
                $EmailBody = "<p><h3>Patch Matrix / Patch Notification Group Sync Results</h3></p>"
                }
            $EmailBody = "$($EmailBody)<h4>$(($GroupChange | Get-Member | Where {$_.MemberType -eq "NoteProperty"}).Name)</h4>"
            Foreach ($item in $GroupChange.$(($GroupChange | Get-Member | Where {$_.MemberType -eq "NoteProperty"}).Name).Additions) {
                $EmailBody = "$($EmailBody)<p style=`"color:green`">Added to the group: $($item)</p>"
                }
            Foreach ($item in $GroupChange.$(($GroupChange | Get-Member | Where {$_.MemberType -eq "NoteProperty"}).Name).Removals) {
                $EmailBody = "$($EmailBody)<p style=`"color:red`">Removed from the group: $($item)</p>"
                }
            }
    }

$i = 0
If ($EmailBody) {
    $MailSuccess = $False
        Do {
            Try {
                $ErrorActionPreference = "Stop"
                $i++
                Send-MailMessage -to "recipient" -From "system@domain" -Subject "Patch Notification Group Sync Results" -BodyAsHtml $EmailBody -SmtpServer smtp.domain.com    
                $MailSuccess = $True
                }
                Catch {
                    Start-Sleep 20
                    }
                Finally {
                    $ErrorActionPreference = "Continue"
                    }
            }
            Until ( $MailSuccess -eq $True -or $i -gt 4 )  
    }