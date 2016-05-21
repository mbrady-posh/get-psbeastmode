# Load up saved repos
$global:Repos = $null
$global:SavedRepos = "$env:USERPROFILE\Documents\repolist.xml"
[xml]$(Get-Content $global:SavedRepos) | Foreach-Object { $_.repos | Foreach-Object { $_.repo | Foreach-Object { [array]$global:Repos = $global:Repos += @{"Name"=$($_.Name);"LocalFolder"=$($_.LocalFolder);"RemoteFolder"=$($_.RemoteFolder)} } } }

Function New-Repo {
[CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True)][string]$LocalFolder,
        [Parameter(Mandatory=$True)][string]$RemoteFolder,
        [Parameter(Mandatory=$True)][string]$FriendlyName,
        [switch]$DoNotSave,
        [switch]$FetchAll
        )
    $VerbosePreference = "Continue"
    If (($Global:Repos | Foreach-Object { $_.Name }) -contains $FriendlyName) {
        Do {
            Write-Verbose "The name $($FriendlyName) is already in use, please use another."
            $FriendlyName = Read-Host -Prompt "FriendlyName"
            }
            While (($Global:Repos | Foreach-Object { $_.Name }) -contains $FriendlyName)
        }
    [array]$global:Repos = $global:Repos += @{"Name"=$FriendlyName;"LocalFolder"=$LocalFolder;"RemoteFolder"=$RemoteFolder}
    If (!($DoNotSave.IsPresent)) {
        "$(Get-Content $global:SavedRepos | Where {$_ -ne "</repos>"})<repo name=`"$($FriendlyName)`"><LocalFolder>$($LocalFolder)</LocalFolder><RemoteFolder>$($RemoteFolder)</RemoteFolder></repo></repos>" | Set-Content $global:SavedRepos -Force
        }
    If ($Fetch) {
        Try {
            Copy-Item $RemoteFolder $LocalFolder -Recurse -Force -Verbose -ErrorVariable $CopyError -ErrorAction "Stop"
            }
            Catch {
                Throw $CopyError
                }
        }
    }

Function Push-RepoFile {
[CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True)][string]$FileName,
        [Parameter(Mandatory=$True)][string]$RepoName
        )
    $VerbosePreference = "Continue"
    Foreach ($Repo in $global:Repos) {
        If ($Repo.Name -eq $RepoName) {
            $script:Destination = $Repo.RemoteFolder
            $script:Source = $Repo.LocalFolder
            }
        }
    If ($FileName.Contains( "\")) {
        $FileParent = "\$(Split-Path $FileName -Parent)"
        }
        Else {
            $FileParent = ""
            }
    If (!$script:Destination) {
        Throw "No repo found by that name."
        }

    If ((Get-Item "$($script:Source)\$($FileName)").PSIsContainer -eq $True) {
        $Choices = @("Y","N")
                $Message = "`nThis is a folder; please confirm you wish to push all contents to the remote folder."
                $Title = ""
                $DefaultChoice = 1
                [System.Management.Automation.Host.ChoiceDescription[]]$Poss = $Choices
                Foreach ($Possible in $Poss) {            
		            New-Object System.Management.Automation.Host.ChoiceDescription "&$($Possible)", "Sets $Possible as an answer." | Out-Null
	                }       
	             $Answer = $Host.UI.PromptForChoice( $Title, $Message, $Poss, $DefaultChoice ) 
                 If ($Answer -eq 0) {
                    Try {
                        $ErrorActionPreference = "Stop"
                        $script:Destination
                        $FileName
                        Copy-Item "$($script:Source)\$($FileName)" "$($script:Destination)$($FileParent)" -Recurse -Force -Verbose -ErrorVariable $CopyErrors
                        }
                        Catch {
                            Throw $CopyErrors
                            }
                        Finally {
                            $ErrorActionPreference = "Continue"
                            }
                    }
                    Else {
                        Exit 1
                        }
            }
            Else {
                Try {
                        $ErrorActionPreference = "Stop"
                        Copy-Item "$($script:Source)\$($FileName)" "$($script:Destination)$($FileParent)" -Recurse -Force -Verbose -ErrorVariable $CopyErrors
                        }
                        Catch {
                            Throw $CopyErrors
                            }
                        Finally {
                            $ErrorActionPreference = "Continue"
                            }
                }
    }

Function Get-RepoList {
[CmdletBinding()]
    $VerbosePreference = "Continue"
    $i = 0
    If ($global:Repos) {
        $global:Repos | Foreach-Object { $i++ ; Write-Verbose "$($i): Repo Name - $($_.Name); Local Folder - $($_.LocalFolder); Remote Folder - $($_.RemoteFolder)" }
        }
        Else {
            Write-Verbose "There are no repos to display."
            }
    }
    
Function Pull-RepoFile {
[CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True)][string]$FileName,
        [Parameter(Mandatory=$True)][string]$RepoName
        )
    If ($FileName.Contains( "\")) {
        $FileParent = "\$(Split-Path $FileName -Parent)"
        }
        Else {
            $FileParent = ""
            }
    $VerbosePreference = "Continue"
    Foreach ($Repo in $global:Repos) {
        If ($Repo.Name -eq $RepoName) {
            $script:Source = $Repo.RemoteFolder
            $script:Destination = $Repo.LocalFolder
            }
        }
    
    If (!$script:Source) {
        Throw "No repo found by that name."
        }

    If ((Get-Item "$($script:Source)\$($FileName)").PSIsContainer -eq $True) {
        $Choices = @("Y","N")
                $Message = "`nThis is a folder; please confirm you wish to overwrite all children in the local copy."
                $Title = ""
                $DefaultChoice = 1
                [System.Management.Automation.Host.ChoiceDescription[]]$Poss = $Choices
                Foreach ($Possible in $Poss) {            
		            New-Object System.Management.Automation.Host.ChoiceDescription "&$($Possible)", "Sets $Possible as an answer." | Out-Null
	                }       
	             $Answer = $Host.UI.PromptForChoice( $Title, $Message, $Poss, $DefaultChoice ) 
                 If ($Answer -eq 0) {
                    Try {
                        $ErrorActionPreference = "Stop"
                        $script:Destination
                        $FileName
                        Copy-Item "$($script:Source)\$($FileName)" "$($script:Destination)$($FileParent)" -Recurse -Force -Verbose -ErrorVariable $CopyErrors
                        }
                        Catch {
                            Throw $CopyErrors
                            }
                        Finally {
                            $ErrorActionPreference = "Continue"
                            }
                    }
                    Else {
                        Exit 1
                        }
            }
            Else {
                Try {
                        $ErrorActionPreference = "Stop"
                        Copy-Item "$($script:Source)\$($FileName)" "$($script:Destination)$($FileParent)" -Recurse -Force -Verbose -ErrorVariable $CopyErrors
                        }
                        Catch {
                            Throw $CopyErrors
                            }
                        Finally {
                            $ErrorActionPreference = "Continue"
                            }
                }
    }

Function Remove-Repo {
[CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True)][string]$RepoName,
        [switch]$DoNotSave,
        [switch]$RemoveFiles
        )
    $VerbosePreference = "Continue"
    If ($Repos | Where {$_.Name -eq "$($RepoName)"}) {
        Try {
            $ErrorActionPreference = "Stop"
            Write-Verbose "Removing $($RepoName) from the repo list."
            $global:Repos = $global:Repos | Where {$_.Name -ne "$($RepoName)"}
            If (!($DoNotSave)) {
                $XMLDoc = [System.Xml.XmlDocument](Get-Content $global:SavedRepos)
                $XMLDoc.Repos.RemoveChild($($XMLDoc.repos.repo | Where {$_.Name -eq $RepoName}))
                $XMLDoc.Save($global:SavedRepos)
                Remove-Variable $XMLDoc
                }
            }
            Catch {
                Throw $error[0]
                }
            }
            Else {
                If (!$Repos) {
                    Write-Verbose "There are no repos to display."
                    Exit 0
                    }
                Write-Verbose "No repo was found with the name $($RepoName)."
                }
        }

Function Diff-Repo {
[CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True)][string]$RepoName
        )
    If (!(($global:Repos | Foreach-Object {$_.Name}) -contains "$($RepoName)" )) {
        Throw "No repo was found with the name $($RepoName)."
        Exit 1
        }
    $VerbosePreference = "Continue"
    $Diffs = Compare-Object  $(Get-ChildItem ($global:Repos | Where {$_.Name -eq "$($RepoName)"}).RemoteFolder -File -Recurse -Force | select FullName,LastWriteTime,@{Name="Combined";Expression={"$($_.Name)::$($_.LastWriteTime)"} }) $(Get-ChildItem ($Global:Repos | Where {$_.Name -eq "$($RepoName)"}).LocalFolder -Recurse -File -Force | select FullName,LastWriteTime,@{Name="Combined";Expression={"$($_.Name)::$($_.LastWriteTime)"} }) -Property "Combined" | Where {($_.sideindicator -eq "<=") -or ($_.sideindicator -eq "=>")}
    $Diffs
    }