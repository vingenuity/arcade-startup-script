
<#PSScriptInfo

.VERSION 1.2.1

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

.PARAMETER ConfigurationFile
 Specifies the path to a configuration file from which all script parameters will be loaded.
 This configuration file MUST be in PowerShell Data (.psd1) format.

.PARAMETER GameBindings
 Specifies the bindings from each input to the arcade game being started.
 AT LEAST one binding MUST be specified!

.PARAMETER NoWaitForConnection
 If set, the script will not wait for an internet connection before starting a game.

.PARAMETER DelayBetweenConnectionChecksSeconds
 Specifies the delay in seconds between each internet connection check.
 The delay can be between 1 and 60 seconds.
 The default is 5 seconds.

.PARAMETER NoSelectGame
 If set, game selection will be skipped, and the default game will be started immediately.

.PARAMETER DelayBetweenSelectionChecksSeconds
 Specifies the delay in seconds between each input check when selecting a game.
 The delay can be between 0 and 10 seconds.
 The default is 0.25 seconds.

.PARAMETER MaxSelectionWaitSeconds
 Specifies the maximum duration in seconds to wait before starting the first game in the GameBindings list.
 The wait can be between 0 and 600 seconds.
 0 seconds means "wait indefinitely".
 The default wait duration is 30 seconds.

.INPUTS
 None. You cannot pipe objects to Start-ArcadeGames.ps1.

.OUTPUTS
 None. Start-ArcadeGames.ps1 does not generate any output.

.EXAMPLE
 C:\PS> .\Start-ArcadeGames.ps1 -ConfigurationFile '.\Start-ArcadeGames.psd1' -InformationAction Continue

.LINK
 https://github.com/vingenuity/arcade-startup-script
#>
[CmdletBinding()]
Param(
    [Parameter(Mandatory, ParameterSetName='Cfg')]
    [ValidateScript({$_ | Test-Path -PathType 'Leaf'})]
    [ValidateScript({[System.IO.Path]::GetExtension($_) -eq '.psd1'})]
    [string]$ConfigurationFile,

    [Parameter(Mandatory, ParameterSetName='Cmd')]
    [AllowEmptyCollection()]  # Empty bindings check done later for better error output.
    [PSObject[]]$GameBindings,

    [Parameter(ParameterSetName='Cmd')]
    [switch]$NoWaitForConnection,

    [Parameter(ParameterSetName='Cmd')]
    [ValidateRange(1, 60)]
    [double]$DelayBetweenConnectionChecksSeconds = 5,

    [Parameter(ParameterSetName='Cmd')]
    [switch]$NoSelectGame,

    [Parameter(ParameterSetName='Cmd')]
    [ValidateRange(0, 10)]
    [double]$DelayBetweenSelectionChecksSeconds = 0.25,

    [Parameter(ParameterSetName='Cmd')]
    [ValidateRange(0, 600)]
    [int]$MaxSelectionWaitSeconds = 30
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
    [OutputType([System.String])]
    Param()
    return Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | Select-Object -ExpandProperty 'Name'
}

<#
.SYNOPSIS
 Loads the contents of a PowerShell configuration file.

.DESCRIPTION
 Loads the contents of a PowerShell configuration file.

.PARAMETER FilePath
 Specifies the path to the PowerShell configuration file to load.

.INPUTS
 None. You cannot pipe objects to Import-PowerShellConfigurationFile.

.OUTPUTS
 Hashtable. Import-PowerShellConfigurationFile returns the configuration contents as a table.

.EXAMPLE
 C:\PS> Import-PowerShellConfigurationFile '.\config.psd1'
 System.Collections.Hashtable
#>
function Import-PowerShellConfigurationFile {
    [OutputType([Hashtable])]
    Param(
        [Parameter(Mandatory, Position=0)]
        [ValidateScript({$_ | Test-Path -PathType 'Leaf'})]
        [string]$FilePath
    )

    if($PSVersionTable.PSVersion.Major -lt 5) {
        return Import-LocalizedData -FileName:$FilePath
    }
    else {
        return Import-PowershellDataFile -Path:$FilePath
    }
}



# Main execution
Write-Information "Importing game configuration file at '$ConfigurationFile'..."
$configurationData = Import-PowerShellConfigurationFile $ConfigurationFile
ForEach($configurationEntry in $configurationData.GetEnumerator()) {
    $configName = $configurationEntry.Name
    $configValue = $configurationEntry.Value

    Write-Verbose "Setting configuration parameter '$configName' to '$($configValue | Out-String)'..."
    Set-Variable -Name:$configName -Value:$configValue -Option 'AllScope'
}

Write-Verbose "Checking game configuration validity..."
if($GameBindings.Count -le 0) { throw [System.ArgumentException] "No game bindings were defined! Cannot start any games." }

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

$gameList = $GameBindings | ForEach-Object { New-Object -TypeName 'PSCustomObject' -Property:$_ }

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
    $maxSelectWaitSeconds = $null
    if($MaxSelectionWaitSeconds -gt 0) {
        Write-Information "Game '$defaultGameName' will start automatically in $MaxSelectionWaitSeconds seconds."
        Write-Information 'Press any of the following inputs to start another game:'
        $maxSelectWaitSeconds = $MaxSelectionWaitSeconds
    }
    else {
        Write-Information 'Press any of the following inputs to start a game:'
        $maxSelectWaitSeconds = [int]::MaxValue 
    }
    $gameList | Select-Object -Property @('Name', 'LocalizedInputName') | Format-Table @{Label='Game'; Expression={$_.Name}},@{Label='Input'; Expression={$_.LocalizedInputName}} | Out-String | ForEach-Object { Write-Information $_ }

    $userSelectedGame = $null
    $selectionTimeoutTime = $(Get-Date) + $(New-TimeSpan -Seconds:$maxSelectWaitSeconds)
    while (($null -eq $userSelectedGame) -and ($(Get-Date) -lt $selectionTimeoutTime)) {
        if(-not $host.ui.RawUI.KeyAvailable) {
            continue
        }

        $keyPressed = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").Character
        Write-Verbose "Key '$keyPressed' was pressed."
        $userSelectedGame = $gameList | Where-Object { $_.KeyName -eq $keyPressed }
        Start-Sleep -Seconds:$DelayBetweenSelectionChecksSeconds
    }
    if($null -ne $userSelectedGame) {
        Write-Information "Game '$($userSelectedGame.Name)' was selected."
        $selectedGame = $userSelectedGame
    }
}

Write-Information "Starting '$($selectedGame.Name)'..."
$startProcessParams = @{ 'FilePath' = $selectedGame.Path }
if($selectedGame.Arguments.Count -gt 0) { $startProcessParams['ArgumentList'] = $selectedGame.Arguments }
Start-Process @startProcessParams
