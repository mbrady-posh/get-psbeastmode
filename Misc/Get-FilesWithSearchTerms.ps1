[CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True)][string]$TopLevelFolder,
        [Parameter(Mandatory=$True)][array]$SearchTerms,
        [Parameter(Mandatory=$True)][string]$OutputFolder,
        [Parameter(Mandatory=$True)][string]$LogFileBaseName
        )

If (!(Test-Path $OutputFolder -Filter {PSisContainer -eq $True})) {
    New-Item $OutputFolder -ItemType Directory | Out-Null
    }

$script:scriptpath = split-path -parent $MyInvocation.MyCommand.Definition

Add-Type -Path "$script:scriptpath\itextsharp.dll"

$ExcludedExtensions = "*.iso","*.msi","*.pst","*.exe","*.dll","*.bin","*.cab","*.mdb","*.mp3","*.jpg","*.gif","*.png","*.jar","*.war","*.src","*.vbs","*.sql","*.js","*.bmp","*.ps1","*.mdf","*.ldf","*.man","*.msu","~*","*.bak","*.dmg"
$WordExtensions = "*.doc*"
$ExcelExtensions = "*.xls*"
$PDFExtensions = "*.pdf"

Get-Childitem -Path $TopLevelFolder -Recurse -Exclude $ExcludedExtensions -Force -Include "*.*" | Foreach-Object {
    Write-Progress -Activity "Reading Files" -CurrentOperation "$($_.FullName)" -status "Working"
    Switch -Wildcard ($_.FullName) { 
        ($WordExtensions) {
            $Path = $_
            $Word = New-Object -ComObject Word.Application
            $Word.Visible = $False
            $Document = $Word.Documents.Open($_)
            $Content = $Document.Content
            $SearchTerms | Foreach-Object {
                $Found = $Content.Find.Execute($_,$False,$False,$False,$False,$False,$True,1)
                }
            If ($Found) {
                Copy-Item $_ $OutputFolder -Force -ErrorVariable CopyErrors -ErrorAction SilentlyContinue
                }
             $Document.Close()
             $Word.Quit()
             [System.Runtime.InteropServices.Marshal]::ReleaseComObject($Content) | Out-Null
             [System.Runtime.InteropServices.Marshal]::ReleaseComObject($Document) | Out-Null
             [System.Runtime.InteropServices.Marshal]::ReleaseComObject($Word) | Out-Null
             $Found = $null
             [System.GC]::Collect()   
             }
        ($ExcelExtensions) {
            $Path = $_
            $Excel = New-Object -ComObject Excel.Application
            $Excel.Visible = $False
            $Document = $Excel.Workbooks.Open($_)
            $Found = $SearchTerms | Foreach-Object {
                $Term = $_
                $Document.Sheets | Foreach-Object {
                    $_.Range("A:ZZ").Find($Term)
                    }
                }
            If ($Found -ne $null) {
                Copy-Item $_ $OutputFolder -Force -ErrorVariable CopyErrors -ErrorAction SilentlyContinue
                }
             $Document.Close()
             $Excel.Quit()
             [System.Runtime.InteropServices.Marshal]::ReleaseComObject($Document) | Out-Null
             [System.Runtime.InteropServices.Marshal]::ReleaseComObject($Excel) | Out-Null           
             $Found = $null
             [System.GC]::Collect() 
             }
        ($PDFExtensions) {
            $Path = $_
            $PDFObj = New-Object iTextSharp.text.PDF.PDFreader -ArgumentList $Path
            $Found = $SearchTerms | Foreach-Object {
                $Term = $_
                For ($Page = 1; $Page -le $PDFObj.NumberOfPages; $Page++) {
                    ([iTextSharp.text.pdf.parser.PdfTextExtractor]::GetTextFromPage($PDFObj, $Page) -split "\r?\n") -like "*$($Term)*"
                    }
                }
            If ($Found) {
                Copy-Item $_ $OutputFolder -Force -ErrorVariable CopyErrors -ErrorAction SilentlyContinue
                }
            $PDFObj.Close()
            $PDFObj = $null
            $Found = $null
            [System.GC]::Collect()
            }
        default {
            If ((Get-Content $_ -Force) | Select-String $SearchTerms) { 
                Copy-Item $_ $OutputFolder  -Force -ErrorVariable CopyErrors -ErrorAction SilentlyContinue
                [System.GC]::Collect()
                } 
                Else {
                    $_ | Out-File C:\users\mbrady2-admin\desktop\nomatch.log -Append
                    }
            }
        }
    }

