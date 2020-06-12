
<#PSScriptInfo

.VERSION 1.0.1

.GUID 8845ad34-cf4a-468a-a188-65f4dc91e7d9

.AUTHOR Vincent Kocks

.COMPANYNAME Vingenuity

.COPYRIGHT 2020 Vincent Kocks

.TAGS

.LICENSEURI

.PROJECTURI

.ICONURI

.EXTERNALMODULEDEPENDENCIES

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES


.PRIVATEDATA

#>

<#
.SYNOPSIS
 Starts one of multiple arcade games selected by the user.

.DESCRIPTION
 Starts one of multiple arcade games selected by the user.

.PARAMETER NoWaitForConnection
 If set, the script will not wait for an internet connection before starting a game.

.PARAMETER DelayBetweenConnectionChecksSeconds
 Specifies the delay in seconds between each internet connection check.
 The delay can be between 1 and 60 seconds.
 The default is 5 seconds.

.PARAMETER NoSelectGame
 If set, game selection will be skipped, and the default game will be started immediately.

.INPUTS
 None. You cannot pipe objects to Start-ArcadeGames.ps1.

.OUTPUTS
 None. Start-ArcadeGames.ps1 does not generate any output.

.EXAMPLE
 C:\PS> .\Start-ArcadeGames.ps1 -InformationAction Continue

.LINK
 https://github.com/vingenuity/arcade-startup-script
#>
[CmdletBinding()]
Param(
    [switch]$NoWaitForConnection,

    [ValidateRange(1, 60)]
    [int]$DelayBetweenConnectionChecksSeconds = 5,

    [switch]$NoSelectGame
)

<#
.SYNOPSIS
 Returns the names of all internet adapters that are currently connected.

.DESCRIPTION
 Returns the names of all internet adapters that are currently connected.

.INPUTS
 None. You cannot pipe objects to Get-ConnectedNetAdapterNames.

.OUTPUTS
 System.String. Get-ConnectedNetAdapterNames returns zero or more net adapter names.

.EXAMPLE
 C:\PS> Get-ConnectedNetAdapterNames
 Ethernet
 Wi-Fi
#>
function Get-ConnectedNetAdapterNames {
    Param()
    return Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | Select-Object -ExpandProperty 'Name'
}



# Main execution
if($NoWaitForConnection -eq $True) {
    Write-Information "Skipping internet connection check due to -NoWaitForConnection being set."
}
else {
    Write-Information 'Waiting for internet connection before starting games...'
    $connectedAdapterNames = Get-ConnectedNetAdapterNames
    while($null -eq $connectedAdapterNames) {
        Write-Verbose "Internet not connected. Waiting $DelayBetweenConnectionChecksSeconds seconds before next check..."
        Start-Sleep -Seconds:$DelayBetweenConnectionChecksSeconds
        $connectedAdapterNames = Get-ConnectedNetAdapterNames
    }
    $firstConnection = $connectedAdapterNames | Select-Object -First 1
    Write-Information "Internet connected on connection '$firstConnection'."
}

$gameList = @(
    @{'Name'='Game 1'; 'Path'='notepad'; 'Arguments'=@(); 'KeyName'='d'; 'LocalizedInputName'='P1 Menu Left'}
    @{'Name'='Game 2'; 'Path'='powershell'; 'Arguments'=@(); 'KeyName'='e'; 'LocalizedInputName'='P1 Start'}
) | ForEach-Object { New-Object -TypeName 'PSCustomObject' -Property:$_ }

$selectedGame = $gameList[0]
$defaultGameName = $selectedGame.Name
if($NoSelectGame -eq $True) {
    Write-Information "Starting default game '$defaultGameName' due to -NoSelectGame being set."
}
elseif(Test-Path variable:global:psISE) {
    # Reading keys does not work in PowerShell ISE.
    Write-Information "Starting default game '$defaultGameName' since running in PowerShell ISE."
}
else {
    Write-Information 'Press any of the following inputs to select the game to start:'
    $gameList | Select-Object -Property @('Name', 'LocalizedInputName') | Format-Table @{Label='Game'; Expression={$_.Name}},@{Label='Input'; Expression={$_.LocalizedInputName}} | Out-String | ForEach-Object { Write-Information $_ }

    $userSelectedGame = $null
    while($null -eq $userSelectedGame) {
        $keyPress = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        Write-Verbose "Key '$($keyPress.Character)' was pressed."
        $userSelectedGame = $gameList | Where-Object { $_.KeyName -eq $keyPress.Character }
    }
    if($null -ne $userSelectedGame) {
        Write-Information "Game '$($userSelectedGame.Name)' was selected."
        $selectedGame = $userSelectedGame
    }
}

Write-Information "Starting '$($selectedGame.Name)'..."
& $selectedGame.Path $selectedGame.Arguments
