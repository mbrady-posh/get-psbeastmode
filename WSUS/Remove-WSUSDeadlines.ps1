[reflection.assembly]::LoadWithPartialName("Microsoft.UpdateServices.Administration") | Out-Null
$WSUSserver = [Microsoft.UpdateServices.Administration.AdminProxy]::GetUpdateServer()

$InstallAction = [Microsoft.UpdateServices.Administration.UpdateApprovalAction]"Install"

$L4GroupIds = $WSUSserver.GetComputerTargetGroups() | Where {($_.Name -like "*Wednesday") -or ($_.Name -like "*Thursday")} | Foreach-Object {$_.Id.Guid}

$UpdateScope = New-Object Microsoft.UpdateServices.Administration.UpdateScope
$UpdateScope.ApprovedStates = "LatestRevisionApproved"
$WSUSServer.GetComputerTargetGroups() | Where {($_.Name -like "*Wednesday") -or ($_.Name -like "*Thursday")} | Foreach-Object { $UpdateScope.ApprovedComputerTargetGroups.Add($_) } | Out-Null

$UpdatestoCheck = $WSUSServer.GetUpdates($UpdateScope)

Foreach ($Update in $UpdatestoCheck) {
    Foreach ($Approval in $Update.GetUpdateApprovals()) {
        If (($Approval.Deadline -lt $(Get-Date "12/30/9999 11:59:59 PM")) -and ($L4GroupIds -contains $Approval.ComputerTargetGroupId)) {
            $ToAdd = $Approval.ComputerTargetGroupId
            $Approval.Delete() | Out-Null
            $Update.Approve($InstallAction,$($WSUSserver.GetComputerTargetGroup([guid]$ToAdd))) | Out-Null
            $ToAdd = $null
            }
        }
    }