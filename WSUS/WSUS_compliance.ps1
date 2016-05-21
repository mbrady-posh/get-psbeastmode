[reflection.assembly]::LoadWithPartialName("Microsoft.UpdateServices.Administration") | Out-Null

$WSUSserver = [Microsoft.UpdateServices.Administration.AdminProxy]::GetUpdateServer()

$AllTargetsScope = New-Object Microsoft.UpdateServices.Administration.computerTargetScope ; $AllTargetsScope.IncludeDownstreamComputerTargets = $True
$AllWSUSTargets = $WSUSserver.GetComputerTargets($AllTargetsScope)
$AllTargetsByCompliance = New-Object -TypeName PSCustomObject
$NonCompliant = New-Object -TypeName PSCustomObject
$Compliant = New-Object -TypeName PSCustomObject
$Overall = New-Object -TypeName PSCustomObject

Function Get-TargetOwner($Target) {
    $TargetGroups = $Target.ComputerTargetGroupIds
    $product = [guid]"guid"
    $PBO = $WSUSserver.GetComputerTargetGroup([guid]"guid").GetChildTargetGroups() | Select Id
    $L3 = $WSUSserver.GetComputerTargetGroup([guid]"guid").GetChildTargetGroups() | Select Id
    $L4 = $WSUSserver.GetComputerTargetGroup([guid]"guid").GetChildTargetGroups() | Select Id
    If ($TargetGroups -contains $product) {
        Return @{Name="product";GUID=($WSUSServer.GetComputerTargetGroup($product) | Select Id).Id}
        }
        ElseIf ( $PBO | Foreach-Object { If ( $TargetGroups -contains $_.Id ) { $True } } ) {
            Return @{Name=$($PBO | Foreach-Object { If ( $TargetGroups -contains $_.Id ) { Return ($WSUSServer.GetComputerTargetGroup("$($_.Id)") | Select Name).Name }});GUID="$(($WSUSserver.GetComputerTargetGroup([guid]"guid") | Select Id).Id)" }
            }
        ElseIf ( $L3 | Foreach-Object { If ( $TargetGroups -contains $_.Id ) { $True } } ) {
            Return @{Name="Internal Sysadmins";GUID=$($L3 | Foreach-Object { If ( $TargetGroups -contains $_.Id ) { Return $_.Id }}) }
            }
        ElseIf ( $L4 | Foreach-Object { If ( $TargetGroups -contains $_.Id ) { $True } } ) {
            Return @{Name="Internal Sysadmins";GUID=$($L4 | Foreach-Object { If ( $TargetGroups -contains $_.Id ) { Return $_.Id }}) }
            }
        Else {
            Return @{Name="Internal Sysadmins";GUID="c2a523d2-a776-4e93-b800-1a5037d4a1de"}
            }
    }

$i = 0
Foreach ($Target in $AllWSUSTargets) {
    $Bad = 0
    $i++
    Write-Progress -Activity "Scanning systems for compliance" -CurrentOperation $Target.FullDomainName -PercentComplete (($i / $AllWSUSTargets.Count) * 100) -SecondsRemaining (3 * ($AllWSUSTargets.Count - $i))
    If (!($Overall.$($Target.FullDomainName))) {
        Add-Member -InputObject $Overall -Name  $($Target.FullDomainName) -MemberType NoteProperty -Value @{"Name"=$($Target.FullDomainName);"LastSyncTime"=$($Target.LastSyncTime);"ResponsibleGroup"=$(Get-TargetOwner $Target).Name; "Updates"=0}
        }
    Foreach ($UpdateInfoColl in $($Target.GetUpdateInstallationInfoPerUpdate())) {
        If (($UpdateInfoColl.UpdateInstallationState -eq "Failed") -or ($UpdateInfoColl.UpdateInstallationState -eq "NotInstalled") -or ($UpdateInfoColl.UpdateInstallationState -eq "Downloaded")) {
            $Update = $wsusServer.GetUpdate($UpdateInfoColl.UpdateId)
            $Approvals =($Update).GetUpdateApprovals()
            If ( (($Approvals | Where-Object {$_.ComputerTargetGroupId -eq "7188f9b8-4454-46a3-9455-23df5efb993c"}).Action -eq "Install") -and (($Update).CreationDate) -lt ((Get-Date).AddDays(-70) )) {
                If (!($NonCompliant.$($Target.FullDomainName))) {
                    Add-Member -InputObject $NonCompliant -Name $($Target.FullDomainName) -MemberType NoteProperty -Value @{"Name"=$($Target.FullDomainName);"LastSyncTime"=$($Target.LastSyncTime);"ResponsibleGroup"=$(Get-TargetOwner $Target).Name; "Updates"=@()}
                    $Bad = 1
                    }
                    $NonCompliant.$($Target.FullDomainName).Updates += @{"UpdateName"=$(($Update).Title);"UpdateCreated"=$(($Update).CreationDate)}
                }
            
            If ((($Approvals | Where-Object {$_.ComputerTargetGroupId -eq "$(($WSUSServer.GetComputerTargetGroup($(Get-TargetOwner $Target).GUID)).GetParentTargetGroup().Id)"}).Action -eq "Install") -or (($Approvals | Where-Object {$_.ComputerTargetGroupId -eq "$((Get-TargetOwner $Target).GUID)"}).Action -eq "Install")) {
                $Overall.$($Target.FullDomainName).Updates = $Overall.$($Target.FullDomainName).Updates + 1
                }
            }
        $Update = $null
        $Approvals = $null
        }
    If ($Bad -eq 0) {
        Add-Member -InputObject $Compliant -Name $($Target.FullDomainName) -MemberType NoteProperty -Value @{"Name"=$($Target.FullDomainName);"LastSyncTime"=$($Target.LastSyncTime);}
        }
    }
Add-Member -InputObject $AllTargetsByCompliance -Name "Compliant" -Value $Compliant -MemberType NoteProperty
Add-Member -InputObject $AllTargetsByCompliance -Name "NonCompliant" -Value $NonCompliant -MemberType NoteProperty
Add-Member -InputObject $AllTargetsByCompliance -Name "Overall" -Value $Overall -MemberType NoteProperty
Return $AllTargetsByCompliance
