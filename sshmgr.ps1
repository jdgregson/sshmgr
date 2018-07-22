# sshmgr - an interactive, text-based SSH connection manager for PowerShell
# Copyright (C) 2018 - jdgregson
# License: GNU GPLv3

$CONNECTION_FOLDER = "~\Documents\sshmgr"
$script:saved_connections = @()
$script:selected = 0
$script:ui_menu_selected_line = 0
$script:ui_last_console_width = (Get-Host).UI.RawUI.WindowSize.Width
$script:command_preview_line = 0
$script:update_ui = $True
$UI_CHAR_BLOCK = " "
$UI_CHAR_BORDER_BOTTOM = "_"
$UI_FOREGROUND_COLOR = (Get-Host).UI.RawUI.ForegroundColor
$UI_BACKGROUND_COLOR = (Get-Host).UI.RawUI.BackgroundColor
$ORIG_FOREGROUND_COLOR = (Get-Host).UI.RawUI.ForegroundColor
$ORIG_BACKGROUND_COLOR = (Get-Host).UI.RawUI.BackgroundColor



#UI code
function Get-UIConsoleWidth() {
    return (Get-Host).UI.RawUI.WindowSize.Width
}


function Get-UIConsoleHeight() {
    return (Get-Host).UI.RawUI.WindowSize.Height
}


function Get-UIPSVersion() {
    return $PSVersionTable.PSVersion.Major
}


function Write-UIText($message) {
    [System.Console]::Write($message)
}

function Pause-UI() {
    cmd /c pause
}


function Write-UIBox($count = 1) {
    if($count -gt 0) {
        Write-UITextInverted $($UI_CHAR_BLOCK * $count)
    }
}


function Reset-UIBufferSize() {
    Set-UIBufferSize (Get-UIConsoleWidth)
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


function Write-UIWrappedText($text, $wrap_anywhere = $False, $width = (Get-UIConsoleWidth)) {
    if($wrap_anywhere) {
        $split = $text -Split ""
        $join = ""
    } else {
        $split = $text -Split " "
        $join = " "
    }
    $finished = $false
    $i = 0
    $written_lines = 0;
    while(-not($finished)) {
        Write-UIBox 3
        $out_line = ""
        for(; $i -lt $split.Count; $i++) {
            if(($split[$i].length + 3) -ge (Get-UIConsoleWidth)) {
                $split[$i] = $split[$i].substring(0, ((Get-UIConsoleWidth) - 8)) + "..."
            }
            if(($out_line.length + 3 + ($split[$i]).length) -lt $width) {
                $out_line += ($split[$i]) + $join
                $finished = $True
            } else {
                $finished = $False
                break
            }
        }
        Write-UITextInverted $out_line
        $written_lines++
        Write-UIBox $($width - ($out_line.length + 3))
        Write-UINewLine
    }
}


function Write-UITitleLine($title) {
    Write-UIWrappedText $title
}


function Write-UIBlankLine($count = 1) {
    for($i=0; $i -lt $count; $i++) {
        Write-UIBox (Get-UIConsoleWidth)
        Write-UINewLine
    }
}


function Write-UINewLine($force = $False) {
    if((Get-UIPSVersion) -eq 5 -or $force -eq $true) {
        [System.Console]::Write("`n")
    }
}


function Set-UICursorOffset($x, $y) {
    $saved_position = (Get-Host).UI.RawUI.CursorPosition
    $saved_position.X = $saved_position.X + $x
    $saved_position.Y = $saved_position.Y + $y
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
    Set-UICursorOffset 0 -3
    Write-UIBox 4
    Write-UITextInverted "$prompt`: "
    return Read-Host
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
    Set-UICursorOffset 0 -2
    Write-UIBox 3
    (Get-Host).UI.RawUI.ForegroundColor = $saved_foreground_color
    (Get-Host).UI.RawUI.BackgroundColor = $saved_background_color
    Pause-UI
}


function Write-UIMenuItem($title, $selected = $False, $width = (Get-UIConsoleWidth)) {
    Write-UIBox
    if($title.length -gt ($width - 5)) {
        $title = $title.Substring(0, ($width - 8)) + "..."
    }
    Write-UIText "  "
    if($selected) {
        Write-UITextInverted $title
        $script:ui_menu_selected_line = (Get-Host).UI.RawUI.CursorPosition.Y
    } else {
        Write-UIText $title
    }
    Write-UIText (" " * ($width - ($title.length) - 4))
    Write-UIBox
    Write-UINewLine
}


function Update-SelectedMenuItem($old_title, $new_title, $direction) {
    Set-UICursorPosition 0 $script:ui_menu_selected_line
    Write-UIMenuItem $old_title
    Set-UICursorPosition 0 ($script:ui_menu_selected_line + $direction)
    $script:selected += $direction
    Write-UIMenuItem $new_title $True
}



# Script logic
function Get-SavedConnections() {
    return @(Get-Item $CONNECTION_FOLDER\*)
}


function New-SavedConnection() {
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


function Connect-SavedConnection($number) {
    if(IsInvalidInput $number) {return}
    Invoke-Expression $(Get-Content $script:saved_connections[$number])
}


function Remove-SavedConnection($number) {
    if(IsInvalidInput $number) {return}
    $name = $script:saved_connections[$number].Name -Replace ".txt"
    $confirmaton = Read-UIPrompt "Delete $name" "Do you really want to delete $name`? " "Enter Y or N"
    if($confirmaton -eq "y") {
        Remove-Item -Force $script:saved_connections[$number]
        if(Test-Path "$CONNECTION_FOLDER\$name.txt") {
            Write-UIError "Unable to delete $name"
        } else {
            $script:selected--
        }
    }
    $script:saved_connections = @(Get-SavedConnections)
}


function Copy-SavedConnection($number) {
    if(IsInvalidInput $number) {return}
    $old_name = $script:saved_connections[$number].Name -Replace ".txt"
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


function Edit-SavedConnection($number) {
    if(IsInvalidInput $number) {return}
    $original_string = Get-Content $script:saved_connections[$number]
    $name = $script:saved_connections[$number].Name
    $new_string = Read-UIPrompt "Edit $name" "Enter the new SSH string for $name (it was `"$original_string`")" "New string"
    if($new_string) {
        $new_string > $script:saved_connections[$number]
    }
    $script:saved_connections = @(Get-SavedConnections)
}


function Rename-SavedConnection($number) {
    if(IsInvalidInput $number) {return}
    $original_name = $script:saved_connections[$number].Name -Replace ".txt"
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


function IsInvalidInput($number) {
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


function Draw-UIMain() {
    Clear-Host

    # draw the commands list
    $menu = "connect: c, ","new: n, ","edit: e, ","rename:r, ","delete: d, ",
        "duplicate: ctrl + d, ","quit: q"
    Write-UITitleLine "COMMANDS"
    Write-UIWrappedText $menu
    Write-UIBlankLine

    # draw the saved connections menu
    $script:saved_connections = @(Get-SavedConnections)
    Write-UITitleLine "SAVED CONNECTIONS"
    for($i=0; $i -lt $script:saved_connections.Count; $i++) {
        $connection = $script:saved_connections[$i]
        $name = $connection.Name -Replace ".txt"
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
    Write-UIBlankLine 2
    Set-UICursorOffset 0 -2
    if($script:saved_connections.Count -gt 0) {
        $text = Get-Content $($script:saved_connections[$script:selected])
    }
    $script:command_preview_line = (Get-Host).UI.RawUI.CursorPosition.Y
    Write-UIWrappedText $text $true
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
            Update-SelectedMenuItem ($script:saved_connections[$script:selected].Name -Replace ".txt") `
                ($script:saved_connections[$script:selected+1].Name -Replace ".txt") 1
            Set-UICursorPosition 0 ($script:command_preview_line)
            Write-UIBlankLine 2
            Set-UICursorPosition 0 ($script:command_preview_line)
            Write-UIWrappedText (Get-Content $script:saved_connections[$script:selected])
        }
    } elseif($input_char.Key -eq [System.ConsoleKey]::UpArrow -or $input_char.Key -eq "K") {
        if($script:selected -gt 0) {
            Update-SelectedMenuItem ($script:saved_connections[$script:selected].Name -Replace ".txt") `
                ($script:saved_connections[$script:selected-1].Name -Replace ".txt") -1
            Set-UICursorPosition 0 ($script:command_preview_line)
            Write-UIBlankLine 2
            Set-UICursorPosition 0 ($script:command_preview_line)
            Write-UIWrappedText (Get-Content $script:saved_connections[$script:selected])
        }
    } elseif(($input_char.Key -eq "C" -and "",0 -contains $input_char.Modifiers) -or
            $input_char.Key -eq "Enter") {
        Clear-Host
        Write-Host "Connecting SSH session..."
        Write-Host "Command: $(Get-Content $script:saved_connections[$script:selected])"
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
