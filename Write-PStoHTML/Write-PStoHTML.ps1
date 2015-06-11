    Function Write-StringtoHTML() {
        [CmdletBinding()]
            Param(
                [Parameter(Mandatory=$True,Position=0)][string]$ID,
                [Parameter(Mandatory=$True,Position=1)][string]$Content,
                [Parameter(Mandatory=$True,Position=2)][string]$HTMLFile
                )
        Set-Location $Global:OriginalPath
        $(Get-Content $HTMLFile) -Replace "&&$ID&&","$Content" | Out-File $HTMLFile
        }

    Function Write-ListtoHTML() {
        [CmdletBinding()]
            Param(
                [Parameter(Mandatory=$True,Position=0)][string]$ID,
                [Parameter(Mandatory=$True,Position=1)][string]$TopLevelContent,
                [Parameter(Mandatory=$True,Position=2)]$ArrayContent,
                [Parameter(Mandatory=$True,Position=3)][string]$HTMLFile
                )
        Set-Location $Global:OriginalPath
        If ($ArrayContent.GetType().Name -eq "String") {
            $ArrayContent = ($ArrayContent -Split "`r`n") ; $ArrayContent = $ArrayContent -ne $ArrayContent[$ArrayContent.Count-1]
            }
        Foreach ($Item in $($ArrayContent | Sort-Object)) {
            $ToWrite = $ToWrite + "<li>$Item</li>"
            }
        $ToWrite = "<ul class=`"collapsibleList`"><li>$TopLevelContent<ul>" + $ToWrite + "</ul></li></ul>"
        $(Get-Content $HTMLFile) -Replace "&&$ID&&","$ToWrite" | Out-File $HTMLFile
        }

    Function Write-ListtoHTMLfromObject() {
        [CmdletBinding()]
            Param(
                [Parameter(Mandatory=$True,Position=0)][string]$ID,
                [Parameter(Mandatory=$True,Position=1)][string]$ParentItemTitle,
                [Parameter(Mandatory=$True,Position=2)]$InputObject,
                [Parameter(Mandatory=$True,Position=3)][string]$HTMLFile
                )
        Set-Location $Global:OriginalPath
        $ToWrite = "<ul class=`"collapsibleList`"><li>$ParentItemTitle<ul class=`"collapsibleList`">"
        Foreach ($NestedObject in $InputObject) {
            $ToWrite = $ToWrite + "<li>$($NestedObject.Name)<ul class=`"collapsibleList`">"
            Foreach ($Property in ($NestedObject | Get-Member | Where-Object {($_.MemberType -like "*Property") -and ($_.Name -ne "Name")} | Select-Object Name)) {
                $ToWrite = $ToWrite + "<li>$($Property.Name): "
                Foreach ($ArrayItem in $($NestedObject.$($Property.Name))) {
                    $ToWrite = $ToWrite + "$ArrayItem<br/>"
                    }
                $ToWrite = $ToWrite + "</li>"
                }
            $ToWrite = $ToWrite + "</ul></li>"
            }
        $ToWrite = $ToWrite + "</ul></li></ul>"                        
        $(Get-Content $HTMLFile) -Replace "&&$ID&&","$ToWrite" | Out-File $HTMLFile
        }

    Function Write-TabletoHTMLfromObject() {
        [CmdletBinding()]
            Param(
                [Parameter(Mandatory=$True,Position=0)][string]$ID,
                [Parameter(Mandatory=$True,Position=1)]$InputObject,
                [Parameter(Mandatory=$True,Position=2)]$PropertyArray,
                [Parameter(Mandatory=$True,Position=3)][string]$HTMLFile
                )
        $ToWrite = "<table><tr>"
        Foreach ($Property in $PropertyArray) {
            $ToWrite = $ToWrite + "<td><strong>$Property</strong></td>"
            }
        $ToWrite = $ToWrite + "</tr>"
        Foreach ($Object in $InputObject) {
            $ToWrite = $ToWrite + "<tr>"
            Foreach ($Property in $PropertyArray) {
                $ToWrite = $ToWrite + "<td>$($Object.$Property)</td>"
                }
            $ToWrite = $ToWrite + "</tr>"
            }
        $ToWrite = $ToWrite + "</table>"
        $(Get-Content $HTMLFile) -Replace "&&$ID&&","$ToWrite" | Out-File $HTMLFile
        }