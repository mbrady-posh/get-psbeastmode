[reflection.assembly]::LoadWithPartialName("Microsoft.UpdateServices.Administration") | Out-Null
$WSUSserver = [Microsoft.UpdateServices.Administration.AdminProxy]::GetUpdateServer()