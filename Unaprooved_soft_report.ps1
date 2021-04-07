#Created by https://github.com/VladimirKosyuk

#Foreach of domain PCs, which OS is Windows 10, collects unapproved installed soft list to csv. 

#About:

 <#
 How to for users:

 0. Examples shown via comments
 1. Define where is folder to output soft.csv at $Output
 2. Define your aprooved soft list key words at $programs.
  
 Notes for developers:

 $NotAprooved array is needed because of -notlike operator at $IsInstalled is ignored by script. But when i try -like it works as expected. So $NotAprooved is workaround.

 #>

# Build date: 07.04.2021

$Output = #'\\MySRV\report'
$Date = Get-Date -Format "MM.dd.yyyy"
$Unic = Get-WmiObject -Class Win32_ComputerSystem |Select-Object -ExpandProperty "Domain"
$list = Get-ADComputer -Filter * -properties *|
            Where-Object {$_.enabled -eq $true} |
                Where-Object {($_.OperatingSystem -like "*Windows 10*")} | Select-Object -ExpandProperty name
foreach ($pc in $list) {
    $Report = Invoke-Command -ComputerName $pc -ErrorAction SilentlyContinue -ScriptBlock {
    [array]$programs =  @(
#'Microsoft'
#'Nvidia'
#'Oracle'
)
Foreach ($program in $programs){
[array]$IsInstalled += @(
(Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\* | ?{($_.DisplayName  -like "*$program*")}).DisplayName
(Get-ItemProperty HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* |?{($_.DisplayName  -like "*$program*")}).DisplayName
)}
ForEach-Object {
[array]$NotAprooved += @(
Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\* |Where-Object DisplayName -NotIn $IsInstalled| Select-Object DisplayName, DisplayVersion, Publisher, InstallLocation
Get-ItemProperty HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* |Where-Object DisplayName -NotIn $IsInstalled| Select-Object DisplayName, DisplayVersion, Publisher, InstallLocation
)}
$NotAprooved| Select-Object @{Name = 'Computername'; Expression = {$env:COMPUTERNAME}}, DisplayName, DisplayVersion, Publisher, InstallLocation
    } -asjob
    Wait-Job $Report -Timeout 300
        if ($Report.State -eq 'Completed') {
        $Report |select State, Location, PSBeginTime, PSEndTime| Out-File $Output\$Unic"_"$Date"_"soft_success.log -Append
        } 
            else {
          $Report |select State, Location, PSBeginTime, PSEndTime|  Out-File $Output\$Unic"_"$Date"_"soft_failed.log -Append
          Stop-Job -Id $Report.Id
          } 
    Receive-Job $Report 4>&1| Select-Object -Property * -ExcludeProperty PSComputerName,RunspaceID, PSShowComputerName |Export-Csv -Append -Delimiter ';' -Path $Output\$Unic"_"$Date"_"soft.csv -Encoding UTF8 -NoTypeInformation
}
Remove-Variable -Name * -Force -ErrorAction SilentlyContinue