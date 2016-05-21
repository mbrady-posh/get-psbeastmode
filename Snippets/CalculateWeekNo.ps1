Function Calculate-WeekNo($Date) {
        $script:Month = Get-Date $Date -Format "MM"
        $script:WeekNo = 1
        Do {
            If ($(Get-Date (($Date).AddDays(-7)) -Format "MM") -eq $script:Month) {
                $script:WeekNo++
                }
            $Date = $Date.AddDays(-7)
            }
            While ( $(Get-Date (($Date).AddDays(-7)) -Format "MM") -eq $script:Month )
        }