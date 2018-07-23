# sshmgr - an interactive, text-based SSH connection manager for PowerShell
# Copyright (C) 2018 - jdgregson
# License: GNU GPLv3

$script_dir = Split-Path -parent $MyInvocation.MyCommand.Path
Import-Module $script_dir\psui1.psm1
$CONNECTION_FOLDER = "~\Documents\sshmgr"
$script:saved_connections = @()
$script:selected = 0
$script:ui_last_console_width = (Get-Host).UI.RawUI.WindowSize.Width
$script:command_preview_line = 0
$script:update_ui = $True
$UI_FOREGROUND_COLOR = (Get-Host).UI.RawUI.ForegroundColor
$UI_BACKGROUND_COLOR = (Get-Host).UI.RawUI.BackgroundColor
$ORIG_FOREGROUND_COLOR = (Get-Host).UI.RawUI.ForegroundColor
$ORIG_BACKGROUND_COLOR = (Get-Host).UI.RawUI.BackgroundColor


function Get-SavedConnections {
    return @(Get-Item $CONNECTION_FOLDER\*)
}


function Get-SavedConnectionName {
    Param(
        [Parameter(Mandatory=$true)]
        [int]$number
    )

    return ($script:saved_connections[$number].Name -Replace ".txt")
}


function Get-SavedConnectionString {
    Param(
        [Parameter(Mandatory=$true)]
        [int]$number
    )

    return (Get-Content $script:saved_connections[$number])
}


function New-SavedConnection {
    $name = Read-UIPrompt "New Saved Connection" "Enter a name for the new saved connection." "Name"
    if(-not($name)) {
        Write-UIError "You must enter a name"
        New-SavedConnection
        return
    }
    $file = "$CONNECTION_FOLDER\$name.txt"
    if(Test-Path -Path $file) {
        Write-UIError "$name already exists"
        New-SavedConnection
        return
    }
    $out = New-Item -Path $file -Type "file" | Out-String
    $string = ""
    do {
        $string = Read-UIPrompt "Enter SSH String" "Enter the SSH string for $name (e.g. `"ssh -p 22 $name`")" "SSH string"
        $string > $file
    } while(-not($string))
    $script:saved_connections = @(Get-SavedConnections)
}


function Connect-SavedConnection {
    Param(
        [Parameter(Mandatory=$true)]
        [int]$number
    )

    if(IsInvalidInput $number) {return}
    Invoke-Expression $(Get-SavedConnectionString $number)
}


function Remove-SavedConnection {
    Param(
        [Parameter(Mandatory=$true)]
        [int]$number
    )

    if(IsInvalidInput $number) {return}
    $name = Get-SavedConnectionName $number
    $confirmaton = Read-UIPrompt "Delete $name" "Do you really want to delete $name`? " "Enter Y or N"
    if($confirmaton -eq "y") {
        Remove-Item -Force $script:saved_connections[$number]
        if(Test-Path "$CONNECTION_FOLDER\$name.txt") {
            Write-UIError "Unable to delete $name"
        } else {
            if($script:selected -gt 0) {
                $script:selected--
            }
        }
    }
    $script:saved_connections = @(Get-SavedConnections)
}


function Copy-SavedConnection {
    Param(
        [Parameter(Mandatory=$true)]
        [int]$number
    )

    if(IsInvalidInput $number) {return}
    $old_name = Get-SavedConnectionName $number
    $name = Read-UIPrompt "Duplicate $old_name" "Enter the name of the new saved connection (a copy of $old_name)" "Name"
    $file = "$CONNECTION_FOLDER\$name.txt"
    if(Test-Path $file) {
        Write-UIError "$name already exists, please enter a different name."
        Copy-SavedConnection $number
        return
    }
    Copy-Item $script:saved_connections[$number] $file
    $script:saved_connections = @(Get-SavedConnections)
}


function Edit-SavedConnection {
    Param(
        [Parameter(Mandatory=$true)]
        [int]$number
    )

    if(IsInvalidInput $number) {return}
    $original_string = Get-SavedConnectionString $number
    $name = $script:saved_connections[$number].Name
    $new_string = Read-UIPrompt "Edit $name" "Enter the new SSH string for $name (it was `"$original_string`")" "New string"
    if($new_string) {
        $new_string > $script:saved_connections[$number]
    }
    $script:saved_connections = @(Get-SavedConnections)
}


function Rename-SavedConnection {
    Param(
        [Parameter(Mandatory=$true)]
        [int]$number
    )

    if(IsInvalidInput $number) {return}
    $original_name = Get-SavedConnectionName $number
    $new_name = Read-UIPrompt "Rename $original_name" "Enter a new name for $original_name" "New name"
    if($new_name -and $new_name -ne $original_name) {
        if(-not(Test-Path "$CONNECTION_FOLDER\$new_name.txt")) {
            Rename-Item $script:saved_connections[$number] "$new_name.txt"
        } else {
            Write-UIError "$new_name already exists, please enter a different name."
            Rename-SavedConnection $number
            return
        }
    }
    $script:saved_connections = @(Get-SavedConnections)
}


function Write-SavedConnectionPreview {
    Param(
        [int]$number
    )

    $connection_string = Get-SavedConnectionString $number
    Set-UICursorPosition 0 ($script:command_preview_line)
    Write-UIBlankLine 3
    Set-UICursorPosition 0 ($script:command_preview_line)
    Write-UIWrappedText $connection_string
}


function IsInvalidInput {
    Param(
        [Parameter(Mandatory=$true)]
        [int]$number
    )

    try {
        $number = [int]$number
    } catch {}
    $too_high = $number -ge $script:saved_connections.Count
    $too_low = $number -lt 0
    $not_a_number = -not($number -is [int])
    if($too_high -or $too_low -or $not_a_number) {
        Write-UIError "INDEX ERROR - $number is not a saved connection" "Debug error"
        return $True
    } else {
        return $False
    }
}


function Draw-UIMain {
    Clear-Host

    # draw the commands list
    $menu = "connect: c, new: n, edit: e, rename:r, delete: d, duplicate: ctrl + d, quit: q"
    Write-UITitleLine "COMMANDS"
    Write-UIWrappedText $menu
    Write-UIBlankLine

    # draw the saved connections menu
    $script:saved_connections = @(Get-SavedConnections)
    Write-UITitleLine "SAVED CONNECTIONS"
    for($i=0; $i -lt $script:saved_connections.Count; $i++) {
        $name = Get-SavedConnectionName $i
        if($i -eq $script:selected) {
            Write-UIMenuItem $name $True
        } else {
            Write-UIMenuItem $name
        }
    }
    if($script:saved_connections.Count -eq 0) {
        Write-UIBox
        $message = "   <none>"
        Write-UIText $message
        Write-UIText (" " * ((Get-UIConsoleWidth) - ($message.length + 2)))
        Write-UIBox
        Write-UINewLine
    }

    # draw the command preview line
    $script:command_preview_line = (Get-Host).UI.RawUI.CursorPosition.Y
    if($script:saved_connections.Count -gt 0) {
        Write-SavedConnectionPreview $script:selected
    } else {
        Write-UIBlankLine 3
    }
}


if(-not(Test-Path $CONNECTION_FOLDER)) {
    $out = mkdir $CONNECTION_FOLDER | Out-String
}
while($True) {
    Reset-UIBufferSize
    if($script:update_ui -or $script:ui_last_console_width -ne (Get-UIConsoleWidth)) {
        Draw-UIMain
        $script:update_ui = $False
        $script:ui_last_console_width = (Get-UIConsoleWidth)
    }

    $input_char = [System.Console]::ReadKey($true)
    if($input_char.Key -eq [System.ConsoleKey]::DownArrow -or $input_char.Key -eq "J") {
        if($script:selected -lt $script:saved_connections.Count-1) {
            $direction = 1
            Update-SelectedMenuItem (Get-SavedConnectionName ($script:selected)) (Get-SavedConnectionName ($script:selected+1)) $direction
            $script:selected += $direction
            Write-SavedConnectionPreview $script:selected
        }
    } elseif($input_char.Key -eq [System.ConsoleKey]::UpArrow -or $input_char.Key -eq "K") {
        if($script:selected -gt 0) {
            $direction = -1
            Update-SelectedMenuItem (Get-SavedConnectionName ($script:selected)) (Get-SavedConnectionName ($script:selected-1)) $direction
            $script:selected += $direction
            Write-SavedConnectionPreview $script:selected
        }
    } elseif(($input_char.Key -eq "C" -and "",0 -contains $input_char.Modifiers) -or
            $input_char.Key -eq "Enter") {
        Clear-Host
        Write-Host "Connecting SSH session..."
        Write-Host "Command: $(Get-SavedConnectionString $script:selected)"
        Connect-SavedConnection $script:selected
        $script:update_ui = $True
    } elseif($input_char.Key -eq "D" -and "",0 -contains $input_char.Modifiers) {
        Remove-SavedConnection $script:selected
        $script:update_ui = $True
    } elseif($input_char.Key -eq "D" -and $input_char.Modifiers -eq "Control") {
        Copy-SavedConnection $script:selected
        $script:update_ui = $True
    } elseif($input_char.Key -eq "N") {
        New-SavedConnection
        $script:update_ui = $True
    } elseif($input_char.Key -eq "E") {
        Edit-SavedConnection $script:selected
        $script:update_ui = $True
    } elseif($input_char.Key -eq "R") {
        Rename-SavedConnection $script:selected
        $script:update_ui = $True
    } elseif($input_char.Key -eq "Q") {
        Clear-Host
        (Get-Host).UI.RawUI.ForegroundColor = $ORIG_FOREGROUND_COLOR
        (Get-Host).UI.RawUI.BackgroundColor = $ORIG_BACKGROUND_COLOR
        Exit
    }
}
