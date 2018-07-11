# sshmgr - an interactive, text-based SSH connection manager for PowerShell
# Copyright (C) 2018 - jdgregson
# License: GNU GPLv3

$CONNECTION_FOLDER = "~\Documents\sshmgr"
$global:saved_connections = @()
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic') | Out-Null


function Get-SavedConnections() {
    return Get-Item $CONNECTION_FOLDER\*
}


function Get-Input($message, $connectionName, $defaultValue) {
    return [Microsoft.VisualBasic.Interaction]::InputBox(
        $message, $connectionName, $defaultValue)
}


function Show-SavedConnections() {
    $global:saved_connections = Get-SavedConnections
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
    if(-not($name)) {
        Write-Host "You must enter a name"
        Create-NewSavedConnection
        return
    }
    $file = "$CONNECTION_FOLDER\$name.txt"
    if(Test-Path $file) {
        Write-Host "$name already exists"
        Create-NewSavedConnection
        return
    }
    $out = New-Item $file | Out-String
    $(Get-Input "Enter the SSH string for $name" $name "ssh -p 22 $name") > $file
    $global:saved_connections = Get-SavedConnections
}


function Connect-SavedConnection($number) {
    Invoke-Expression $(Get-Content $global:saved_connections[$number])
}


function Delete-SavedConnection($number) {
    Remove-Item -Force $global:saved_connections[$number]
    $global:saved_connections = Get-SavedConnections
}


function Copy-SavedConnection($number) {
    $name = Read-Host "Enter new saved connection name"
    $file = "$CONNECTION_FOLDER\$name.txt"
    Copy-Item $global:saved_connections[$number] $file
    $global:saved_connections = Get-SavedConnections
}


function Edit-SavedConnection($number) {
    $original_string = Get-Content $global:saved_connections[$number]
    $name = $global:saved_connections[$number].Name
    $new_string = Get-Input "Enter the SSH string for $name" $name $original_string
    if($new_string) {
        $new_string > $global:saved_connections[$number]
    }
    $global:saved_connections = Get-SavedConnections
}


function Edit-SavedConnectionNotepad($number) {
    notepad.exe $global:saved_connections[$number] | Out-Null
    $global:saved_connections = Get-SavedConnections
}


function Rename-SavedConnection($number) {
    $original_name = $global:saved_connections[$number].Name
    $new_name = Read-Host "Enter new name for $original_name"
    if($new_name -and $new_name -ne $original_name) {
        Rename-Item $global:saved_connections[$number] $new_name
    }
    $global:saved_connections = Get-SavedConnections
}


function Show-Help() {
    $help = New-Object System.Collections.ArrayList;
    $help.Add($(New-Object PSObject -Prop @{'Command'='args';'Description'='Show SSH arguments';'Example'='args';'Alias'=''})) | Out-Null
    $help.Add($(New-Object PSObject -Prop @{'Command'='connect';'Description'='Connect to a saved connection';'Example'='connect 1';'Alias'='c'})) | Out-Null
    $help.Add($(New-Object PSObject -Prop @{'Command'='copy';'Description'='Copy a saved connection';'Example'='copy 1';'Alias'='C, cp'})) | Out-Null
    $help.Add($(New-Object PSObject -Prop @{'Command'='delete';'Description'='Delete a saved connection';'Example'='delete 1';'Alias'='d, rm, del'})) | Out-Null
    $help.Add($(New-Object PSObject -Prop @{'Command'='edit';'Description'='Edit a saved connection';'Example'='edit 1';'Alias'='e'})) | Out-Null
    $help.Add($(New-Object PSObject -Prop @{'Command'='exit';'Description'='Exit sshmgr';'Example'='exit';'Alias'='exit, bye, x'})) | Out-Null
    $help.Add($(New-Object PSObject -Prop @{'Command'='help';'Description'='Show this help message';'Example'='help';'Alias'='?, h'})) | Out-Null
    $help.Add($(New-Object PSObject -Prop @{'Command'='list';'Description'='List saved connections';'Example'='list';'Alias'='l, ls, dir'})) | Out-Null
    $help.Add($(New-Object PSObject -Prop @{'Command'='new';'Description'='Create a new saved connection';'Example'='new';'Alias'='n'})) | Out-Null
    $help.Add($(New-Object PSObject -Prop @{'Command'='notepad';'Description'='Edit a saved connection in notepad';'Example'='notepad 1';'Alias'='np'})) | Out-Null
    $help.Add($(New-Object PSObject -Prop @{'Command'='rename';'Description'='Rename a saved connection';'Example'='rename 1';'Alias'='r, ren'})) | Out-Null
    #$help.Add($(New-Object PSObject -Prop @{'Command'='x';'Description'='x';'Example'='x';'Alias'='x'})) | Out-Null
    $help | Sort-Object Command | Format-Table -Property Command,Description,Example,Alias -AutoSize
}


function Process-Command($command) {
    $command = $command -split " ",2
    $c = $command[0]
    $arg = $command[1]
    if($c -in "args") {
        ssh
    } elseif($c -in "connect","c") {
        Connect-SavedConnection $arg
    } elseif($c -in "copy","c","cp") {
        Copy-SavedConnection $arg
    } elseif($c -in "delete","rm","del","d") {
        Delete-SavedConnection $arg
    } elseif($c -in "edit","e") {
        Edit-SavedConnection $arg
    } elseif($c -in "exit","x","bye","quit") {
        Exit
    } elseif($c -in "?","help","h") {
        Show-Help
    } elseif($c -in "list","l","ls","dir") {
        Show-SavedConnections
    } elseif($c -in "new","n") {
        Create-NewSavedConnection
    } elseif($c -in "notepad","np") {
        Edit-SavedConnectionNotepad $arg
    }  elseif($c -in "rename","r","ren") {
        Rename-SavedConnection $arg
    } else {
        Write-Host "Unknown command"
    }
    Write-Host
}


if(-not(Test-Path $CONNECTION_FOLDER)) {
    $out = mkdir $CONNECTION_FOLDER | Out-String
}
$global:saved_connections = Get-SavedConnections
Show-SavedConnections
Write-Host
Write-Host "Enter ? for help"
while($True) {
    Process-Command $(Read-Host "[sshmgr] Enter command")
}
