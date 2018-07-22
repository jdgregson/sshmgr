
# psui1 - a basic, text-based user interface module for PowerShell
# Copyright (C) 2018 - jdgregson
# License: GNU GPLv3


function Get-UIBlockChar() {
    if($script:ui_block_char) {
        return $script:ui_block_char
    } else {
        return " "
    }
}


function Set-UIBlockChar($char) {
    $script:ui_block_char = $char
}


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
        Write-UITextInverted $((Get-UIBlockChar) * $count)
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
