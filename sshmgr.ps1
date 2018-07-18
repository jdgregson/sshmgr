# sshmgr - an interactive, text-based SSH connection manager for PowerShell
# Copyright (C) 2018 - jdgregson
# License: GNU GPLv3

$CONNECTION_FOLDER = "~\Documents\sshmgr"
$global:saved_connections = @()
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic') | Out-Null
$global:selected = 0;
$update_ui = $True
$UI_CHAR_BLOCK = " "
$UI_CHAR_BORDER_BOTTOM = "_"



#UI code
function Get-UIConsoleWidth() {
    return (Get-Host).UI.RawUI.WindowSize.Width
}


function Get-UIConsoleHeight() {
    return (Get-Host).UI.RawUI.WindowSize.Height
}


function Write-UIText($message) {
    [System.Console]::Write($message)
}


function Write-UITextInverted($message) {
    $saved_background_color = (Get-Host).UI.RawUI.BackgroundColor
    $saved_foreground_color = (Get-Host).UI.RawUI.ForegroundColor
    (Get-Host).UI.RawUI.ForegroundColor = $saved_background_color
    (Get-Host).UI.RawUI.BackgroundColor = $saved_foreground_color
    [System.Console]::Write($message);
    (Get-Host).UI.RawUI.ForegroundColor = $saved_foreground_color
    (Get-Host).UI.RawUI.BackgroundColor = $saved_background_color
}


function Write-UIBox($count = 1) {
    if($count -gt 0) {
        Write-UITextInverted $($UI_CHAR_BLOCK * $count)
    }
}


function Write-UIWrappedText($text, $wrap_anywhere = $False) {
    if($wrap_anywhere) {
        $split = $text -Split ""
        $join = ""
    } else {
        $split = $text -Split " "
        $join = " "
    }
    $finished = $false
    $i = 0
    while(-not($finished)) {
        Write-UIBox 3
        $out_line = ""
        for(; $i -lt $split.Count; $i++) {
            if(($out_line.length + 3 + ($split[$i]).length) -lt (Get-UIConsoleWidth)) {
                $out_line += ($split[$i]) + $join
                $finished = $True
            } else {
                $finished = $False
                break
            }
        }
        Write-UITextInverted $out_line
        Write-UIBox $((Get-UIConsoleWidth) - ($out_line.length + 3))
        Write-UINewLine
    }
}


function Write-UITitleLine($title) {
    Write-UIBox 3
    Write-UITextInverted $title
    Write-UIBox $((Get-UIConsoleWidth) - ($title.length + 3))
    Write-UINewLine
}


function Write-UIBlankLine() {
    Write-UIBox (Get-UIConsoleWidth)
    Write-UINewLine
}


function Write-UINewLine() {
    [System.Console]::Write("`n")
}


function Set-UICursorOffset($offset) {
    $saved_position = (Get-Host).UI.RawUI.CursorPosition
    $saved_position.Y = $saved_position.Y + $offset
    (Get-Host).UI.RawUI.CursorPosition = $saved_position
}


function Set-UICursorPosition($x, $y) {
    $saved_position = (Get-Host).UI.RawUI.CursorPosition
    $saved_position.X = $x
    $saved_position.Y = $y
    (Get-Host).UI.RawUI.CursorPosition = $saved_position
}


function Set-UIBufferSize($width = $False, $height = $False) {
    $saved_buffer = (Get-Host).UI.RawUI.BufferSize
    if(-not($width -eq $False)) {
        $saved_buffer.Width = $width
    }
    if(-not($height -eq $False)) {
        $saved_buffer.Height = $height
    }
    (Get-Host).UI.RawUI.BufferSize = $saved_buffer
}


function Reset-UIBufferSize() {
    Set-UIBufferSize (Get-UIConsoleWidth)
}


function Read-UIPrompt($title, $text, $prompt) {
    Reset-UIBufferSize
    Set-UICursorPosition 0 0
    Write-UITitleLine $title
    Write-UIBlankLine
    Write-UIWrappedText $text
    Write-UIBlankLine
    Write-UIBlankLine
    Write-UIBlankLine
    Write-UIText (($UI_CHAR_BORDER_BOTTOM) * (Get-UIConsoleWidth))
    Set-UICursorOffset -3
    Write-UIBox 4
    return Read-Host $prompt
}


function Write-UIError($message, $title = "Error") {
    Reset-UIBufferSize
    Set-UICursorPosition 0 0
    $saved_background_color = (Get-Host).UI.RawUI.BackgroundColor
    $saved_foreground_color = (Get-Host).UI.RawUI.ForegroundColor
    (Get-Host).UI.RawUI.ForegroundColor = "White"
    (Get-Host).UI.RawUI.BackgroundColor = "DarkRed"
    Write-UITitleLine $title
    Write-UIBlankLine
    Write-UIWrappedText $message
    Write-UIBlankLine
    Write-UIBlankLine
    Write-UIBlankLine
    Set-UICursorOffset -2
    Write-UIBox 3
    (Get-Host).UI.RawUI.ForegroundColor = $saved_foreground_color
    (Get-Host).UI.RawUI.BackgroundColor = $saved_background_color
    Pause
}



# Script logic
function Get-SavedConnections() {
    return Get-Item $CONNECTION_FOLDER\*
}


function New-SavedConnection() {
    $name = Read-UIPrompt "New Saved Connection" "Enter a name for the new saved connection." "Name"
    if(-not($name)) {
        Write-UIError "You must enter a name"
        New-SavedConnection
        return
    }
    $file = "$CONNECTION_FOLDER\$name.txt"
    if(Test-Path $file) {
        Write-UIError "$name already exists"
        New-SavedConnection
        return
    }
    $out = New-Item $file | Out-String
    $string = ""
    do {
        $string = Read-UIPrompt "Enter SSH String" "Enter the SSH string for $name (e.g. `"ssh -p 22 $name`")" "SSH string"
        $string > $file
    } while(-not($string))
    $global:saved_connections = Get-SavedConnections
}


function Connect-SavedConnection($number) {
    if(IsInvalidInput $number) {return}
    Invoke-Expression $(Get-Content $global:saved_connections[$number])
}


function Remove-SavedConnection($number) {
    if(IsInvalidInput $number) {return}
    $name = $global:saved_connections[$number].Name -Replace ".txt"
    $confirmaton = Read-UIPrompt "Delete $name" "Do you really want to delete $name`? " "Enter Y or N"
    if($confirmaton -eq "y") {
        Remove-Item -Force $global:saved_connections[$number]
        if(Test-Path "$CONNECTION_FOLDER\$name.txt") {
            Write-UIError "Unable to delete $name"
        } else {
            $global:selected--
        }
    }
    $global:saved_connections = Get-SavedConnections
}


function Copy-SavedConnection($number) {
    if(IsInvalidInput $number) {return}
    $old_name = $global:saved_connections[$number].Name -Replace ".txt"
    $name = Read-UIPrompt "Duplicate $old_name" "Enter the name of the new saved connection (a copy of $old_name)" "Name"
    $file = "$CONNECTION_FOLDER\$name.txt"
    if(Test-Path $file) {
        Write-UIError "$name already exists, please enter a different name."
        Copy-SavedConnection $number
        return
    }
    Copy-Item $global:saved_connections[$number] $file
    $global:saved_connections = Get-SavedConnections
}


function Edit-SavedConnection($number) {
    if(IsInvalidInput $number) {return}
    $original_string = Get-Content $global:saved_connections[$number]
    $name = $global:saved_connections[$number].Name
    $new_string = Read-UIPrompt "Edit $name" "Enter the new SSH string for $name (it was `"$original_string`")" "New string"
    if($new_string) {
        $new_string > $global:saved_connections[$number]
    }
    $global:saved_connections = Get-SavedConnections
}


function Rename-SavedConnection($number) {
    if(IsInvalidInput $number) {return}
    $original_name = $global:saved_connections[$number].Name -Replace ".txt"
    $new_name = Read-UIPrompt "Rename $original_name" "Enter a new name for $original_name" "New name"
    if($new_name -and $new_name -ne $original_name) {
        if(-not(Test-Path "$CONNECTION_FOLDER\$new_name.txt")) {
            Rename-Item $global:saved_connections[$number] "$new_name.txt"
        } else {
            Write-UIError "$new_name already exists, please enter a different name."
            Rename-SavedConnection $number
            return
        }
    }
    $global:saved_connections = Get-SavedConnections
}


function IsInvalidInput($number) {
    try {
        $number = [int]$number
    } catch {}
    $too_high = $number -ge $global:saved_connections.Count
    $too_low = $number -lt 0
    $not_a_number = -not($number -is [int])
    if($too_high -or $too_low -or $not_a_number) {
        Write-UIError "INDEX ERROR - $number is not a saved connection" "Debug error"
        return $True
    } else {
        return $False
    }
}


function Draw-UIMain() {
    Clear-Host

    # draw the commands list
    $menu = "connect = c","new = n","edit = e","rename = r","delete = d","duplicate = ctrl + d"
    Write-UITitleLine "COMMANDS"
    Write-UIWrappedText $menu
    Write-UIBlankLine

    # draw the saved connections menu
    $global:saved_connections = Get-SavedConnections
    Write-UITitleLine "SAVED CONNECTIONS"
    for($i=0; $i -lt $global:saved_connections.Count; $i++) {
        $connection = $global:saved_connections[$i]
        $name = $connection.Name -Replace ".txt"
        Write-UIBox
        if($name.length -gt ((Get-UIConsoleWidth) - 5)) {
            $name = $name.Substring(0, ((Get-UIConsoleWidth) - 8)) + "..."
        }
        Write-UIText "  "
        if($i -eq $global:selected) {
            Write-UITextInverted $name
        } else {
            Write-UIText $name
        }
        Write-UIText (" " * ((Get-UIConsoleWidth) - ($name.length) - 4))
        Write-UIBox
        Write-UINewLine
    }

    # draw the command preview line
    $text = Get-Content $($global:saved_connections[$global:selected])
    Write-UIWrappedText $text $true
}


while($True) {
    Reset-UIBufferSize
    if($update_ui) {
        Draw-UIMain
        $update_ui = $False
    }

    $input_char = [System.Console]::ReadKey($true)
    if($input_char.Key -eq [System.ConsoleKey]::DownArrow) {
        if($global:selected -lt $global:saved_connections.Count-1) {
            $global:selected++
            $update_ui = $True
        }
    } elseif($input_char.Key -eq [System.ConsoleKey]::UpArrow) {
        if($global:selected -gt 0) {
            $global:selected--
            $update_ui = $True
        }
    } elseif($input_char.Key -eq "C" -and $input_char.Modifiers -eq "") {
        Clear-Host
        Write-Host "Connecting SSH session..."
        Write-Host "Command: $(Get-Content $global:saved_connections[$global:selected])"
        Connect-SavedConnection $global:selected
        $update_ui = $True
    } elseif($input_char.Key -eq "D" -and $input_char.Modifiers -eq "") {
        Remove-SavedConnection $global:selected
        $update_ui = $True
    } elseif($input_char.Key -eq "D" -and $input_char.Modifiers -eq "Control") {
        Copy-SavedConnection $global:selected
        $update_ui = $True
    } elseif($input_char.Key -eq "N") {
        New-SavedConnection
        $update_ui = $True
    } elseif($input_char.Key -eq "E") {
        Edit-SavedConnection $global:selected
        $update_ui = $True
    } elseif($input_char.Key -eq "R") {
        Rename-SavedConnection $global:selected
        $update_ui = $True
    }
}
