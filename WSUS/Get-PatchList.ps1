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

$CurrentDate = Get-Date

$Dayvalue = $CurrentDate.DayOfWeek.value__ + 1
$DayofWeek = $CurrentDate.DayOfWeek
$Daynum = Get-Date $CurrentDate -Format "dd"
$script:Month = Get-Date $CurrentDate -Format "MM"

$script:WeekNo = 1

Function Calculate-WeekNo($Date) {
    Do {
        If ($(Get-Date (($Date).AddDays(-7)) -Format "MM") -eq $script:Month) {
            $script:WeekNo++
            }
        $Date = $Date.AddDays(-7)
        }
        While ( $(Get-Date (($Date).AddDays(-7)) -Format "MM") -eq $script:Month )
    }

Calculate-WeekNo $CurrentDate

$serverlist = $listobj.data.row | Where {$_.ows_Future_x0020_Tier_x0020_Grouping -like "$($script:WeekNo)*$($DayofWeek)*" }| Select ows_Title,ows_Future_x0020_Tier_x0020_Grouping

$Selected = New-Object PSCustomObject
Foreach ($item in $serverlist) {
    Add-Member -MemberType NoteProperty -InputObject $Selected -Name $Item.ows_Title -Value "[x]" -Force
    }
$cursor = 1 + $($serverlist.Count)
$Serverlistobj = Foreach ($item in $serverlist) {
            New-Object PSCustomObject -Property @{"Selected"=$($Selected.$($item.ows_Title));"Name"=$($item.ows_Title);"Group"=$($item.ows_Future_x0020_Tier_x0020_Grouping)}
            }
$i = 0
$IDtohostname = @{}
Foreach ($object in $Serverlistobj) {
    $IDtohostname += @{$($i)=$($object.Name)}
    $i++
    }
Do {
        Clear-Host
        Write-Host "Server List" -ForegroundColor Cyan
        Foreach ($item in $Serverlistobj) {
           If ($item.Selected -eq "[ ]") {
                $Fontcolor = "Red"
                }
                Else {
                    $Fontcolor = "DarkGreen"
                    }
            If ($($IDtohostname.-((-$($serverlistobj.count) - 2)+$($cursor+1))) -eq $item.Name) {
                Write-Host ("{0,-3} {1,-37} {2,-20}" -f $($item.Selected),$($item.Name),$($item.Group)) -ForegroundColor $Fontcolor -BackgroundColor White
                }
                Else {
                    Write-Host ("{0,-3} {1,-37} {2,-20}" -f $($item.Selected),$($item.Name),$($item.Group)) -ForegroundColor $Fontcolor
                }
            }
        Write-Host "**********Use up/down keys to navigate, space to select***************" -ForegroundColor Cyan
        $cursorposition = $host.ui.RawUI.CursorPosition
        $Cursorposition.Y = $cursorposition.Y - $cursor
        $host.UI.RawUI.CursorPosition = $cursorposition
        $key = $null
        $key = $host.ui.rawui.ReadKey("NoEcho,IncludeKeyDown")
        If ($key.VirtualKeyCode -eq "38") {
             If (((-$($serverlist.count) - 2)+$($cursor+1)) -in -$($serverlist.count)..-1) {
                $cursor++
                }
             }
             ElseIf ($key.VirtualKeyCode -eq "40") {
                If (((-$($serverlist.count) - 2)+$($cursor-1)) -in -$($serverlist.count)..-1) {
                    $cursor = $cursor - 1
                    }
                }
            ElseIf ($key.virtualkeycode -eq "32") {
                If ($serverlistobj[-((-$($serverlistobj.count) - 2)+$($cursor+1))])  {
                    If ($serverlistobj[-((-$($serverlistobj.count) - 2)+$($cursor+1))].Selected -eq "[x]") {
                        Add-Member -InputObject $serverlistobj[-((-$($serverlistobj.count) - 2)+$($cursor+1))] -Name Selected -Value "[ ]" -Force -MemberType NoteProperty
                        }
                        Else {
                            Add-Member -InputObject $serverlistobj[-((-$($serverlistobj.count) - 2)+$($cursor+1))] -Name Selected -Value "[x]"-Force -MemberType NoteProperty
                            }
                        }
                    }
            ElseIf ($key.virtualkeycode -eq "13") {
                $editedlist = $serverlistobj | Where {$_.Selected -eq "[x]"}
                Do {
                    Clear-Host
                    Foreach ($item in $editedlist) {
                        Write-Host $($item.Name) -ForegroundColor DarkGreen
                        }
                    $Choices = @("Y","N")
                    $Message = "`nWould you like to add any servers to this list?"
                    $Title = ""
                    $DefaultChoice = 1
                    [System.Management.Automation.Host.ChoiceDescription[]]$Poss = $Choices
                    Foreach ($Possible in $Poss) {            
		                New-Object System.Management.Automation.Host.ChoiceDescription "&$($Possible)", "Sets $Possible as an answer." | Out-Null
	                    }       
	                 $Answer = $Host.UI.PromptForChoice( $Title, $Message, $Poss, $DefaultChoice ) 
                     If ($Answer -eq 0) {
                        $name = Read-Host -Prompt "Server Name"
                        $editedlist += New-Object PSCustomObject -Property @{"Name"=$name}
                        }
                        Else {
                            Return $editedlist.Name
                            }
                    }
                    Until ($answer -eq 1)
                    }
            ElseIf ($key.character -eq "q") {
                Clear-Host
                $Choices = @("Y","N")
                $Message = "`nAre you sure you want to exit?"
                $Title = ""
                $DefaultChoice = 1
                [System.Management.Automation.Host.ChoiceDescription[]]$Poss = $Choices
                Foreach ($Possible in $Poss) {            
		            New-Object System.Management.Automation.Host.ChoiceDescription "&$($Possible)", "Sets $Possible as an answer." | Out-Null
	                }       
	             $Answer = $Host.UI.PromptForChoice( $Title, $Message, $Poss, $DefaultChoice ) 
                 If ($Answer -eq 0) {
                    Clear-Host
                    Get-Job | Remove-Job -Force
                    Exit 0
                    }
                    Else {
                        $key = $null
                        }
                }
        Start-sleep -Milliseconds 500
        }
        While ($true -eq $true)