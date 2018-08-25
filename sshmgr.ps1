# sshmgr - A text-based GUI SSH connection manager for PowerShell.
# Copyright (C) 2018 - jdgregson
# License: GNU GPLv3

$script_dir = Split-Path -parent $MyInvocation.MyCommand.Path
Import-Module $script_dir\psui1.psm1 -Force
$CONNECTION_FOLDER = "~\Documents\sshmgr"
$script:saved_connections = @()
$script:selected_page = 0
$script:selected_item = 0
$script:ui_last_console_width = (Get-Host).UI.RawUI.WindowSize.Width
$script:ui_last_console_width = (Get-Host).UI.RawUI.WindowSize.Height
$script:command_preview_line = 0
$script:update_ui = $True
$script:available_lines = 0
$script:pages = $Null
$UI_FOREGROUND_COLOR = (Get-Host).UI.RawUI.ForegroundColor
$UI_BACKGROUND_COLOR = (Get-Host).UI.RawUI.BackgroundColor
$ORIG_FOREGROUND_COLOR = (Get-Host).UI.RawUI.ForegroundColor
$ORIG_BACKGROUND_COLOR = (Get-Host).UI.RawUI.BackgroundColor


function Get-SavedConnections {
    return (Get-ChildItem $CONNECTION_FOLDER\* | Where {(-not $_.PSIsContainer)})
}


function Get-SavedConnectionPages {
    $script:saved_connections = @(Get-SavedConnections)
    $script:pages = @{}
    $i = 0
    $j = 0
    while($i -lt $script:saved_connections.Count) {
        $script:pages[$j] = @{}
        for($k=0; $k -lt $script:available_lines; $k++) {
            if(($i + $k) -ge $script:saved_connections.Count) {break}
            $script:pages[$j][$k] = $script:saved_connections[(($j * $script:available_lines) + $k)]
        }
        $i += $script:available_lines
        $j += 1
    }
    return $script:pages
}


function Get-SavedConnectionName {
    Param(
        [int]$page_number = $script:selected_page,
        [int]$item_number = $script:selected_item,
        [bool]$FullUpdate = $False
    )

    if($FullUpdate -eq $True) {
        $script:pages = Get-SavedConnectionPages
    }
    if($script:pages.Count -ge 1) {
        try {
            return ($script:pages[$page_number][$item_number].Name -Replace ".txt")
        } catch {
            return ""
        }
    }
}


function Get-SavedConnectionString {
    Param(
        [int]$page_number = $script:selected_page,
        [int]$item_number = $script:selected_item,
        [bool]$FullUpdate = $False
    )

    if($FullUpdate -eq $True) {
        $script:pages = Get-SavedConnectionPages
    }
    if($script:pages.Count -ge 1) {
        try {
            return (Get-Content $script:pages[$page_number][$item_number])
        } catch {
            return ""
        }
    }
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
        Write-UIError "'$name' already exists"
        New-SavedConnection
        return
    }
    $out = New-Item -Path $file -Type "file" | Out-String
    $string = ""
    do {
        $string = Read-UIPrompt "Enter SSH String" "Enter the SSH string for '$name' (e.g. `"ssh -p 22 $name`")" "SSH string"
        $string > $file
    } while(-not($string))
    $script:saved_connections = @(Get-SavedConnections)
}


function Connect-SavedConnection {
    Param(
        [int]$page_number = $script:selected_page,
        [int]$item_number = $script:selected_item
    )

    try {
        Invoke-Expression $(Get-SavedConnectionString $page_number $item_number)
        Wait-AnyKey
    } catch {
        $name = (Get-SavedConnectionName $page_number $item_number)
        $string = (Get-SavedConnectionString $page_number $item_number)
        $error_msg = $_.Exception.Message
        Write-UIError "Error connecting to '$name'`: $error_msg The connection string was`: $string" "Connection Error"
    }
}


function Remove-SavedConnection {
    Param(
        [int]$page_number = $script:selected_page,
        [int]$item_number = $script:selected_item
    )

    $name = Get-SavedConnectionName $page_number $item_number
    $confirmaton = Read-UIPrompt "Delete '$name'" "Do you really want to delete '$name'`? " "Enter Y or N" "N"
    if($confirmaton -eq "y") {
        Remove-Item -Force $script:pages[$page_number][$item_number]
        if(Test-Path "$CONNECTION_FOLDER\$name.txt") {
            Write-UIError "Unable to delete '$name'"
        } else {
            if($script:selected_item -gt 0) {
                $script:selected_item--
            }
        }
    }
    $script:update_ui = $True
}


function Copy-SavedConnection {
    Param(
        [int]$page_number = $script:selected_page,
        [int]$item_number = $script:selected_item
    )

    $old_name = Get-SavedConnectionName $page_number $item_number
    $name = Read-UIPrompt "Duplicate '$old_name'" "Enter the name of the new saved connection (a copy of '$old_name')" "Name" $old_name
    $file = "$CONNECTION_FOLDER\$name.txt"
    if(Test-Path $file) {
        Write-UIError "'$name' already exists, please enter a different name."
        Copy-SavedConnection $page_number $item_number
        return
    }
    if(-not $name) {
        Write-UIError "You must enter a new name."
        Copy-SavedConnection $page_number $item_number
        return
    }
    Copy-Item $script:pages[$page_number][$item_number] $file
    $script:update_ui = $True
}


function Edit-SavedConnection {
    Param(
        [int]$page_number = $script:selected_page,
        [int]$item_number = $script:selected_item
    )

    $original_string = Get-SavedConnectionString $page_number $item_number
    $name = Get-SavedConnectionName $page_number $item_number
    $new_string = Read-UIPrompt "Edit '$name'" "Enter the new SSH string for '$name' (it was '$original_string')" "New string" $original_string
    if($new_string) {
        $new_string > $script:pages[$page_number][$item_number]
    }
    $script:update_ui = $True
}


function Rename-SavedConnection {
    Param(
        [int]$page_number = $script:selected_page,
        [int]$item_number = $script:selected_item
    )

    $original_name = Get-SavedConnectionName $page_number $item_number
    $new_name = Read-UIPrompt "Rename '$original_name'" "Enter a new name for '$original_name'" "New name" $original_name
    if($new_name -and $new_name -ne $original_name) {
        if(-not(Test-Path "$CONNECTION_FOLDER\$new_name.txt")) {
            Rename-Item $script:pages[$page_number][$item_number] "$new_name.txt"
        } else {
            Write-UIError "'$new_name' already exists, please enter a different name."
            Rename-SavedConnection $page_number $item_number
            return
        }
    }
    $script:update_ui = $True
}


function Write-SavedConnectionPreview {
    $connection_string = Get-SavedConnectionString
    Set-UICursorPosition 0 ($script:command_preview_line)
    Write-UIBlankLine 3
    Set-UICursorPosition 0 ($script:command_preview_line)
    Write-UIWrappedText $connection_string -MaxLines 3
}


function Draw-UIMain {
    Clear-Host

    # draw the commands list
    $menu = "connect: c, new: n, edit: e, rename:r, delete: d, duplicate: ctrl + d, quit: q"
    Write-UITitleLine "COMMANDS"
    Write-UIWrappedText $menu
    Write-UIBlankLine

    $available_lines_offset = 5
    $script:available_lines = (Get-UIConsoleHeight) - ((Get-UICursorPositionY) + $available_lines_offset)
    if($script:available_lines -lt 1) {
        $script:available_lines = 1
    }
    $lines_used = 0
    $name = Get-SavedConnectionName -FullUpdate $False

    # draw the saved connections menu
    Write-UIBlankLine
    $script:pages = Get-SavedConnectionPages
    Set-UICursorOffset -y -1
    Write-UIWrappedText "SAVED CONNECTIONS (page $($script:selected_page + 1) of $($script:pages.Count))"
    for($i=0; $i -lt $script:pages[$script:selected_page].Count; $i++, $lines_used++) {
        if($i -eq $script:selected_item) {
            Write-UIMenuItem (Get-SavedConnectionName $script:selected_page $i) $True
        } else {
            Write-UIMenuItem (Get-SavedConnectionName $script:selected_page $i)
        }
    }
    if($script:saved_connections.Count -eq 0) {
        Write-UIMenuItem "<none>"
        $script:available_lines -= 1
    }

    for($i=0; $i -lt ($script:available_lines - $lines_used); $i++) {
        Write-UIBox
        Write-UIText (" " * ((Get-UIConsoleWidth) - 2))
        Write-UIBox
        Write-UINewLine
    }

    # draw the command preview line
    $script:command_preview_line = (Get-Host).UI.RawUI.CursorPosition.Y
    if($script:saved_connections.Count -gt 0) {
        Write-SavedConnectionPreview ($script:selected_item + $script:selected_page)
    } else {
        Write-UIBlankLine 3
    }
}


if(-not(Test-Path $CONNECTION_FOLDER)) {
    $out = mkdir $CONNECTION_FOLDER | Out-String
}
while($True) {
    Reset-UIBufferSize
    if($script:update_ui -or $script:ui_last_console_width -ne (Get-UIConsoleWidth) -or $script:ui_last_console_height -ne (Get-UIConsoleHeight)) {
        if($script:ui_last_console_width -ne (Get-UIConsoleWidth) -or $script:ui_last_console_height -ne (Get-UIConsoleHeight)) {
            $script:selected_page = 0
            $script:selected_item = 0
        }
        Draw-UIMain
        $script:update_ui = $False
        $script:ui_last_console_width = (Get-UIConsoleWidth)
        $script:ui_last_console_height = (Get-UIConsoleHeight)
    }

    $input_char = [System.Console]::ReadKey($true)
    if($input_char.Key -eq [System.ConsoleKey]::DownArrow -or $input_char.Key -eq "J") {
        if($script:selected_item -lt $script:pages[$script:selected_page].Count-1) {
            $direction = 1
            Update-UISelectedMenuItem (Get-SavedConnectionName) (Get-SavedConnectionName $script:selected_page ($script:selected_item + $direction)) $direction
            $script:selected_item += $direction
            Write-SavedConnectionPreview
        } elseif($script:selected_page -ne ($script:pages.Count - 1) -and $script:selected_item -lt $script:pages[$script:selected_page].Count) {
            $script:selected_page += 1
            $script:selected_item = 0
            $script:update_ui = $True
        }
    } elseif($input_char.Key -eq [System.ConsoleKey]::UpArrow -or $input_char.Key -eq "K") {
        if($script:selected_item -gt 0) {
            $direction = -1
            Update-UISelectedMenuItem (Get-SavedConnectionName) (Get-SavedConnectionName $script:selected_page ($script:selected_item + $direction)) $direction
            $script:selected_item += $direction
            Write-SavedConnectionPreview
        } elseif($script:selected_page -gt 0) {
            $script:selected_page -= 1
            $script:selected_item = ($script:available_lines - 1)
            $script:update_ui = $True
        }
    } elseif(($input_char.Key -eq "C" -and "",0 -contains $input_char.Modifiers) -or
            $input_char.Key -eq "Enter") {
        Clear-Host
        Write-Host "Connecting SSH session..."
        Write-Host ("Command: " + (Get-SavedConnectionString))
        Connect-SavedConnection
        $script:update_ui = $True
    } elseif($input_char.Key -eq "D" -and "",0 -contains $input_char.Modifiers) {
        Remove-SavedConnection
        $script:update_ui = $True
    } elseif($input_char.Key -eq "D" -and $input_char.Modifiers -eq "Control") {
        Copy-SavedConnection
        $script:update_ui = $True
    } elseif($input_char.Key -eq "N") {
        New-SavedConnection
        $script:update_ui = $True
    } elseif($input_char.Key -eq "E") {
        Edit-SavedConnection
        $script:update_ui = $True
    } elseif($input_char.Key -eq "R") {
        Rename-SavedConnection
        $script:update_ui = $True
    } elseif($input_char.Key -eq "Q") {
        Clear-Host
        (Get-Host).UI.RawUI.ForegroundColor = $ORIG_FOREGROUND_COLOR
        (Get-Host).UI.RawUI.BackgroundColor = $ORIG_BACKGROUND_COLOR
        Exit
    }
}
