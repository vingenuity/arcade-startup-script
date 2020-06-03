[CmdletBinding()]
Param(
    [switch]$NoWaitForConnection,

    [ValidateRange(1, 60)]
    [int]$DelayBetweenConnectionChecksSeconds = 5,

    [switch]$NoSelectGame
)

function Get-ConnectedAdapterNames {
    Param()
    return Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | Select-Object -ExpandProperty 'Name'
}

if($NoWaitForConnection -eq $True) {
    Write-Information "Skipping internet connection check due to -NoWaitForConnection being set."
}
else {
    Write-Information 'Waiting for internet connection before starting games...'
    $connectedAdapterNames = Get-ConnectedAdapterNames
    while($null -eq $connectedAdapterNames) {
        Write-Verbose "Internet not connected. Waiting $DelayBetweenConnectionChecksSeconds seconds before next check..."
        Start-Sleep -Seconds:$DelayBetweenConnectionChecksSeconds
        $connectedAdapterNames = Get-ConnectedAdapterNames
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
