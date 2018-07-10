# sshmgr - an interactive, text-based SSH connection manager for PowerShell
# Copyright (C) 2018 - jdgregson
# License: GNU GPLv3

$CONNECTION_FOLDER = "~\Documents\sshmgr"
$global:saved_connections = @{}


function Get-SavedConnections() {
    return Get-Item $CONNECTION_FOLDER\*
}


function Show-SavedConnections() {
    Write-Host "Saved Connections:"
    if($global:saved_connections.Count -gt 0) {
        for($i = 0; $i -lt $global:saved_connections.Count; $i++) {
            $name = $global:saved_connections[$i].Name -Replace ".txt"
            Write-Host " $i`: $name"
        }
    } else {
        Write-Host " <none>"
    }
}


function Create-NewSavedConnection() {
    $name = Read-Host "Enter new saved connection name"
    $file = "$CONNECTION_FOLDER\$name.txt"
    if(Test-Path $file) {
        Write-Host "$name already exists"
        Create-NewSavedConnection
        return
    }
    New-Item $file
    "ssh -p 22 $name" > $file
    notepad.exe $file
}


function Connect-SavedConnection($number) {
    Invoke-Expression $(Get-Content $global:saved_connections[$number])
}


function Delete-SavedConnection($number) {
    Remove-Item -Force $global:saved_connections[$number]
    return Get-SavedConnections
}


function Show-Help() {
    $help = New-Object System.Collections.ArrayList;
    $help.Add($(New-Object PSObject -Prop @{'Command'='connect';'Description'='Connect to a saved connection';'Example'='connect 1';'Alias'='c'})) | Out-Null
    $help.Add($(New-Object PSObject -Prop @{'Command'='edit';'Description'='Edit a saved connection';'Example'='edit 1';'Alias'='e'})) | Out-Null
    $help.Add($(New-Object PSObject -Prop @{'Command'='new';'Description'='Create a new saved connection';'Example'='new';'Alias'='n'})) | Out-Null
    $help.Add($(New-Object PSObject -Prop @{'Command'='delete';'Description'='Delete a saved connection';'Example'='delete 1';'Alias'='d'})) | Out-Null
    $help.Add($(New-Object PSObject -Prop @{'Command'='copy';'Description'='Copy a saved connection';'Example'='copy 1';'Alias'='C'})) | Out-Null
    $help.Add($(New-Object PSObject -Prop @{'Command'='list';'Description'='List saved connections';'Example'='list';'Alias'='l'})) | Out-Null
    $help.Add($(New-Object PSObject -Prop @{'Command'='exit';'Description'='Exit sshmgr';'Example'='exit';'Alias'='exit, bye, x'})) | Out-Null
    $help.Add($(New-Object PSObject -Prop @{'Command'='args';'Description'='Show SSH arguments';'Example'='args';'Alias'=''})) | Out-Null
    $help.Add($(New-Object PSObject -Prop @{'Command'='help';'Description'='Show this help message';'Example'='help';'Alias'='?, h'})) | Out-Null
    $help.Add($(New-Object PSObject -Prop @{'Command'='x';'Description'='x';'Example'='x';'Alias'='x'})) | Out-Null
    $help | Format-Table
}


function Process-Command($command) {
    if($command -eq "args") {
        ssh
    } elseif($command -match "c \d") {
        Connect-SavedConnection $($command -Replace "c ")
    } elseif($command -eq "n") {
        Create-NewSavedConnection
        $global:saved_connections = Get-SavedConnections
    } elseif($command -match "d \d") {
        Delete-SavedConnection $($command -Replace "d ")
    } elseif($command -eq "?" -or $command -eq "help") {
        Show-Help
    } elseif($command -eq "l" -or $command -eq "list") {
        Show-SavedConnections
    }
}


$global:saved_connections = Get-SavedConnections
Show-SavedConnections
Write-Host
while($command = Read-Host "Enter command (enter ? for help)") {
    Process-Command $command
    Write-Host
}
