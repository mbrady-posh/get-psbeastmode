[CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True,Position=1)]
            [string]$PW
    )
    
$Numbers = 0 .. ($PW.Length -1)

$PhoneticPass = ""

Foreach ($Number in $Numbers) {
    Switch -CaseSensitive ($PW[$Number] ){
        "a" { $PhoneticPass = "$PhoneticPass Alpha " }
        "b" {$PhoneticPass = "$PhoneticPass Beta " }
        "c" {$PhoneticPass = "$PhoneticPass Charlie "}
        "d" { $PhoneticPass = "$PhoneticPass Delta "}
        "e" {$PhoneticPass = "$PhoneticPass Echo "}
        "f" {$PhoneticPass = "$PhoneticPass Foxtrot "}
        "g" {$PhoneticPass = "$PhoneticPass Golf "}
        "h" {$PhoneticPass = "$PhoneticPass Hotel "}
        "i" {$PhoneticPass = "$PhoneticPass India "}
        "j" {$PhoneticPass = "$PhoneticPass Juliett "}
        "k" {$PhoneticPass = "$PhoneticPass Kilo "}
        "l" {$PhoneticPass = "$PhoneticPass Lima "}
        "m" {$PhoneticPass = "$PhoneticPass Mike "}
        "n" {$PhoneticPass = "$PhoneticPass November "}
        "o" {$PhoneticPass = "$PhoneticPass Oscar "}
        "p" {$PhoneticPass = "$PhoneticPass Papa "}
        "q" {$PhoneticPass = "$PhoneticPass Quebec "}
        "r" {$PhoneticPass = "$PhoneticPass Romeo "}
        "s" {$PhoneticPass = "$PhoneticPass Sierra "}
        "t" {$PhoneticPass = "$PhoneticPass Tango "}
        "u" {$PhoneticPass = "$PhoneticPass Uniform "}
        "v" {$PhoneticPass = "$PhoneticPass Victor "}
        "w" {$PhoneticPass = "$PhoneticPass Whiskey "}
        "x" {$PhoneticPass = "$PhoneticPass Xray "}
        "y" {$PhoneticPass = "$PhoneticPass Yankee "}
        "z" {$PhoneticPass = "$PhoneticPass Zulu "}
         # Capitals
         "A" { $PhoneticPass = "$PhoneticPass CAPITAL ALPHA " }
        "B" {$PhoneticPass = "$PhoneticPass CAPITAL BETA " }
        "C" {$PhoneticPass = "$PhoneticPass CAPITAL CHARLIE "}
        "D" { $PhoneticPass = "$PhoneticPass CAPITAL DELTA "}
        "E" {$PhoneticPass = "$PhoneticPass CAPITAL ECHO "}
        "F" {$PhoneticPass = "$PhoneticPass CAPITAL FOXTROT "}
        "G" {$PhoneticPass = "$PhoneticPass CAPITAL GOLF "}
        "H" {$PhoneticPass = "$PhoneticPass CAPITAL HOTEL "}
        "I" {$PhoneticPass = "$PhoneticPass CAPITAL INDIA "}
        "J" {$PhoneticPass = "$PhoneticPass CAPITAL JULIETT "}
        "K" {$PhoneticPass = "$PhoneticPass CAPITAL KILO "}
        "L" {$PhoneticPass = "$PhoneticPass CAPITAL LIMA "}
        "M" {$PhoneticPass = "$PhoneticPass CAPITAL MIKE "}
        "N" {$PhoneticPass = "$PhoneticPass CAPITAL NOVEMBER "}
        "O" {$PhoneticPass = "$PhoneticPass CAPITAL OSCAR "}
        "P" { $PhoneticPass = "$PhoneticPass CAPITAL PAPA " }
         "Q" {$PhoneticPass = "$PhoneticPass CAPITAL QUEBEC "}
        "R" {$PhoneticPass = "$PhoneticPass CAPITAL ROMEO "}
        "S" {$PhoneticPass = "$PhoneticPass CAPITAL SIERRA "}
        "T" {$PhoneticPass = "$PhoneticPass CAPITAL TANGO "}
        "U" {$PhoneticPass = "$PhoneticPass CAPITAL UNIFORM "}
        "V" {$PhoneticPass = "$PhoneticPass CAPITAL VICTOR "}
        "W" {$PhoneticPass = "$PhoneticPass CAPITAL WHISKEY "}
        "X" {$PhoneticPass = "$PhoneticPass CAPITAL XRAY "}
        "Y" {$PhoneticPass = "$PhoneticPass CAPITAL YANKEE "}
        "Z" {$PhoneticPass = "$PhoneticPass CAPITAL ZULU "}
        # Numbers
         "1" {$PhoneticPass = "$PhoneticPass Number One "}
        "2" {$PhoneticPass = "$PhoneticPass Number Two "}
        "3" {$PhoneticPass = "$PhoneticPass Number Three "}
        "4" {$PhoneticPass = "$PhoneticPass Number Four "}
        "5" {$PhoneticPass = "$PhoneticPass Number Five "}
        "6" {$PhoneticPass = "$PhoneticPass Number Six "}
        "7" {$PhoneticPass = "$PhoneticPass Number Seven "}
        "8" {$PhoneticPass = "$PhoneticPass Number Eight "}
        "9" {$PhoneticPass = "$PhoneticPass Number Nine "}
        "0" {$PhoneticPass = "$PhoneticPass Number Zero "}
        # Else
        default { $PhoneticPass = "$PhoneticPass $($PW[$Number]) Symbol " }
        }
    }

Write-Output $PhoneticPass

$PW = $null
$PhoneticPass = $null