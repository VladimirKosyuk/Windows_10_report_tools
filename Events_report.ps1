#Created by https://github.com/VladimirKosyuk

#Foreach of domain PCs, which OS is Windows 10, collects system log critical and error events list during last month to csv. 

# Build date: 07.04.2021

$Output = #'\\MySRV\report'
$Date = Get-Date -Format "MM.dd.yyyy"
$Unic = Get-WmiObject -Class Win32_ComputerSystem |Select-Object -ExpandProperty "Domain"
$list = Get-ADComputer -Filter * -properties *|
            Where-Object {$_.enabled -eq $true} |
                Where-Object {($_.OperatingSystem -like "*Windows 10*")} | Select-Object -ExpandProperty name


foreach ($pc in $list) {
$error.Clear()
$Events = Invoke-Command -ComputerName $pc -ScriptBlock {
$VerbosePreference='Continue'
Get-EventLog -LogName System -After (Get-Date).AddMonths(-1) |
? { $_.entryType -Match "Error" -and "Critical" } |
Group-Object -Property EventID |
% { $_.Group[0] | Add-Member -PassThru -MemberType NoteProperty -Name Count -Value $_.Count }|
Select-Object MachineName, EventID, Count, Message

} -AsJob
Wait-Job $Events -Timeout 300
if ($Events.State -eq 'Completed') {
$Events |select State, Location, PSBeginTime, PSEndTime| Out-File $Output\$Unic"_"$Date"_"events_success.log -Append
} 
    else {
  $Events |select State, Location, PSBeginTime, PSEndTime|  Out-File $Output\$Unic"_"$Date"_"events_failed.log -Append
  Stop-Job -Id $Events.Id
} 
Receive-Job $Events 4>&1| Select-Object -Property * -ExcludeProperty PSComputerName,RunspaceID, PSShowComputerName |Export-Csv -Append -Delimiter ';' -Path $Output\$Unic"_"$Date"_"events.csv -Encoding UTF8 -NoTypeInformation
}

Remove-Variable -Name * -Force -ErrorAction SilentlyContinue
