#Created by https://github.com/VladimirKosyuk

#Foreach of domain PCs, which OS is Windows 10, runs DISM /Online /Cleanup-Image /CheckHealth and output to cli.

#Note_1 - the idea is to run cmd commands centralized, it's not necessary needs to be DISM.
#Note_2 - ConvertTo-Encoding got from https://xaegr.wordpress.com/2007/01/24/decoder/   

# Build date: 07.04.2021

$list = Get-ADComputer -Filter * -properties *|
            Where-Object {$_.enabled -eq $true} |
                Where-Object {($_.OperatingSystem -like "*Windows 10*")} | Select-Object -ExpandProperty name

foreach ($pc in $list) {

    function ConvertTo-Encoding ([string]$From, [string]$To){
	Begin{
		$encFrom = [System.Text.Encoding]::GetEncoding($from)
		$encTo = [System.Text.Encoding]::GetEncoding($to)
	}
	Process{
		$bytes = $encTo.GetBytes($_)
		$bytes = [System.Text.Encoding]::Convert($encFrom, $encTo, $bytes)
		$encTo.GetString($bytes)
	}
}
    
       Invoke-Command -ScriptBlock {
       $env:COMPUTERNAME
       DISM /Online /Cleanup-Image /CheckHealth 
       } -ComputerName $pc | ConvertTo-Encoding -From cp866 -To windows-1251
}

Remove-Variable -Name * -Force -ErrorAction SilentlyContinue