# psui1 - a text-based user interface module for PowerShell
# Copyright (C) 2018 - jdgregson
# License: GNU GPLv3


Set-Alias -Name "Pause-UI" -Value "Wait-AnyKey"
$script:ui_menu_selected_line = 0
$UI_CHAR_BORDER_BOTTOM = "_"
$UIColors = "Black","DarkBlue","DarkGreen","DarkCyan","DarkRed","DarkMagenta",
    "DarkYellow","Gray","DarkGray","Blue","Green","Cyan","Red","Magenta",
    "Yellow","White"


function Get-UIBlockChar {
    if($script:ui_block_char) {
        return $script:ui_block_char
    } else {
        return " "
    }
}


function Set-UIBlockChar {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Character
    )

    $script:ui_block_char = $Character
}


function Get-UIConsoleWidth {
    return (Get-Host).UI.RawUI.WindowSize.Width
}


function Get-UIConsoleHeight {
    return (Get-Host).UI.RawUI.WindowSize.Height
}


function Get-UIPSVersion {
    return $PSVersionTable.PSVersion.Major
}


function Write-UIText {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Message
    )

    [System.Console]::Write($Message);
}


function Write-UIColoredText {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [string]$BackgroundColor = (Get-Host).UI.RawUI.BackgroundColor,
        [string]$ForegroundColor = (Get-Host).UI.RawUI.ForegroundColor
    )

    $saved_background_color = (Get-Host).UI.RawUI.BackgroundColor
    $saved_foreground_color = (Get-Host).UI.RawUI.ForegroundColor
    (Get-Host).UI.RawUI.ForegroundColor = $ForegroundColor
    (Get-Host).UI.RawUI.BackgroundColor = $BackgroundColor
    [System.Console]::Write($Message);
    (Get-Host).UI.RawUI.ForegroundColor = $saved_foreground_color
    (Get-Host).UI.RawUI.BackgroundColor = $saved_background_color
}


function Wait-AnyKey {
    cmd /c pause
}


function Write-UIBox {
    Param(
        [int]$Count = 1
    )

    if($Count -gt 0) {
        Write-UITextInverted $((Get-UIBlockChar) * $Count)
    }
}


function Reset-UIBufferSize {
    Set-UIBufferSize (Get-UIConsoleWidth)
}


function Write-UITextInverted {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Message
    )

    $saved_background_color = (Get-Host).UI.RawUI.BackgroundColor
    $saved_foreground_color = (Get-Host).UI.RawUI.ForegroundColor
    (Get-Host).UI.RawUI.ForegroundColor = $saved_background_color
    (Get-Host).UI.RawUI.BackgroundColor = $saved_foreground_color
    [System.Console]::Write($Message);
    (Get-Host).UI.RawUI.ForegroundColor = $saved_foreground_color
    (Get-Host).UI.RawUI.BackgroundColor = $saved_background_color
}


function Write-UIWrappedText {
    Param(
        [string]$Text = "",
        [bool]$WrapAnywhere = $False,
        [int]$Width = (Get-UIConsoleWidth),
        [int]$MaxLines = 0
    )

    if($WrapAnywhere) {
        $split = $Text -Split ""
        $join = ""
    } else {
        $split = $Text -Split " "
        $join = " "
    }
    $finished = $false
    $i = 0
    $written_lines = 0;
    while($Text -and (-not $finished) -and (-not ($MaxLines -gt 0 -and $written_lines -ge $MaxLines))) {
        Write-UIBox 3
        $out_line = ""
        for(; $i -lt $split.Count; $i++) {
            if(($split[$i].length + 3) -ge (Get-UIConsoleWidth)) {
                $split[$i] = $split[$i].substring(0, ((Get-UIConsoleWidth) - 8)) + "..."
            }
            if(($out_line.length + 3 + ($split[$i]).length) -lt $Width) {
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


function Write-UITitleLine {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Title
    )

    Write-UIWrappedText $Title
}


function Write-UIBlankLine {
    Param(
        [int]$Count = 1
    )

    for($i=0; $i -lt $Count; $i++) {
        Write-UIBox (Get-UIConsoleWidth)
        Write-UINewLine
    }
}


function Write-UINewLine {
    Param(
        [bool]$Force = $False
    )

    if((Get-UIPSVersion) -eq 5 -or $Force -eq $True) {
        [System.Console]::Write("`n")
    }
}


function Write-UIBorder {
    Param(
        [int]$Height = 0,
        [int]$Width = 0,
        [int]$StartX = 0,
        [int]$StartY = 0,
        [string]$BorderCharacter = " "
    )

    if($Height -and $Width) {
        Throw "Cannot specify both height and width"
    }

    $original_position_x = (Get-UICursorPositionX)
    $original_position_y = (Get-UICursorPositionX)
    Set-UICursorPosition -x $StartX -y $StartY
    if($Height) {
        While(((Get-UICursorPositionY) + $StartY) -lt $Height) {
            Write-UITextInverted $BorderCharacter
            Set-UICursorPosition -x $StartX -y ((Get-UICursorPositionY) + 1)
        }
    } elseif($Width) {
        While(((Get-UICursorPositionX) + $StartX) -lt $Width) {
            Write-UITextInverted $BorderCharacter
            if((Get-UICursorPositionX) -ge (Get-UIConsoleWidth) - 1) {
                Write-UITextInverted $BorderCharacter
                break
            }
        }
    }
    Set-UICursorPosition -x $original_position_x -y $original_position_y
}


function Set-UICursorOffset {
    Param(
        [int]$X = 0,
        [int]$Y = 0
    )

    $saved_position = (Get-Host).UI.RawUI.CursorPosition
    $saved_position.X = $saved_position.X + $X
    $saved_position.Y = $saved_position.Y + $Y
    (Get-Host).UI.RawUI.CursorPosition = $saved_position
}


function Set-UICursorPosition {
    Param(
        [int]$X = 0,
        [int]$Y = 0
    )

    if($X -lt 0) {$X = 0}
    if($X -ge (Get-UIConsoleWidth)) {$X = (Get-UIConsoleWidth) - 1}
    if($Y -lt 0) {$Y = 0}
    if($Y -ge (Get-UIConsoleHeight)) {$Y = (Get-UIConsoleHeight) - 1}

    $saved_position = (Get-Host).UI.RawUI.CursorPosition
    $saved_position.X = $X
    $saved_position.Y = $Y
    try {
        (Get-Host).UI.RawUI.CursorPosition = $saved_position
    } catch {
        Throw "The cursor position $saved_position is out of bounds."
    }
}


function Get-UICursorPositionX {
    return (Get-Host).UI.RawUI.CursorPosition.X
}


function Get-UICursorPositionY {
    return (Get-Host).UI.RawUI.CursorPosition.Y
}


function Get-UIColorsAtPosition {
    Param(
        [Parameter(Mandatory=$true)]
        [int]$X,
        [Parameter(Mandatory=$true)]
        [int]$Y
    )

    $colors = (Get-Host).UI.RawUI.GetBufferContents(@{
        Left=$X; Right=$X; Top=$Y; Bottom=$Y;
    })
    return @{
        ForegroundColor=$colors.ForegroundColor;
        BackgroundColor=$colors.BackgroundColor;
    }
}


function Set-UIBufferSize {
    Param(
        [int]$Width = 0,
        [int]$Height = 0
    )

    $saved_buffer = (Get-Host).UI.RawUI.BufferSize
    if(-not($Width -eq 0)) {
        $saved_buffer.Width = $Width
    }
    if(-not($Height -eq 0)) {
        $saved_buffer.Height = $Height
    }
    (Get-Host).UI.RawUI.BufferSize = $saved_buffer
}


function Read-UIPrompt {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Title,
        [Parameter(Mandatory=$true)]
        [string]$Text,
        [Parameter(Mandatory=$true)]
        [string]$Prompt,
        [string]$DefaultValue = ""
    )

    Reset-UIBufferSize
    Set-UICursorPosition 0 0
    Write-UITitleLine $Title
    Write-UIBlankLine
    Write-UIWrappedText $Text
    Write-UIBlankLine 4
    Write-UIText $(($UI_CHAR_BORDER_BOTTOM) * (Get-UIConsoleWidth))
    Set-UICursorOffset 0 -4
    Write-UIBox 4
    Write-UITextInverted "$Prompt`: "
    if($DefaultValue) {
        $saved_position_x = (Get-UICursorPositionX)
        $saved_position_y = (Get-UICursorPositionY)
        Write-UIColoredText $DefaultValue -ForegroundColor Yellow
        Set-UICursorPosition -x $saved_position_x -y $saved_position_y
    }
    return Read-Host
}


function Write-UIError {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [string]$Title = "Error"
    )

    Reset-UIBufferSize
    Set-UICursorPosition 0 0
    $saved_background_color = (Get-Host).UI.RawUI.BackgroundColor
    $saved_foreground_color = (Get-Host).UI.RawUI.ForegroundColor
    (Get-Host).UI.RawUI.ForegroundColor = "White"
    (Get-Host).UI.RawUI.BackgroundColor = "DarkRed"
    Write-UITitleLine $Title
    Write-UIBlankLine
    Write-UIWrappedText $Message
    Write-UIBlankLine
    Write-UIBlankLine
    Write-UIBlankLine
    Set-UICursorOffset 0 -2
    Write-UIBox 3
    (Get-Host).UI.RawUI.ForegroundColor = $saved_foreground_color
    (Get-Host).UI.RawUI.BackgroundColor = $saved_background_color
    Wait-AnyKey
}


function Write-UIMenuItem {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Title,
        [bool]$Selected = $False,
        [int]$Width = (Get-UIConsoleWidth)
    )

    Write-UIBox
    if($Title.length -gt ($Width - 5)) {
        $Title = $Title.Substring(0, ($Width - 8)) + "..."
    }
    Write-UIText "  "
    if($Selected) {
        Write-UITextInverted $Title
        $script:ui_menu_selected_line = (Get-Host).UI.RawUI.CursorPosition.Y
    } else {
        Write-UIText $Title
    }
    Write-UIText (" " * ($Width - ($Title.length) - 4))
    Write-UIBox
    Write-UINewLine
}


function Update-UISelectedMenuItem {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$OldTitle,
        [Parameter(Mandatory=$true)]
        [string]$NewTitle,
        [Parameter(Mandatory=$true)]
        [int]$Direction
    )

    Set-UICursorPosition 0 $script:ui_menu_selected_line
    Write-UIMenuItem $OldTitle
    Set-UICursorPosition 0 ($script:ui_menu_selected_line + $Direction)
    Write-UIMenuItem $NewTitle $True
}


function Get-UIRandomCharacter {
    return ([char]$(Get-Random -Min 33 -Max 128))
}


function Get-UIRandomColor {
    return $UIColors[$(Get-Random -Min 0 -Max $UIColors.Count)]
}


function Draw-UIScreenBomb {
    while($True) {
        Write-Host (Get-UIRandomCharacter) -NoNewline -BackgroundColor (Get-UIRandomColor) -ForegroundColor (Get-UIRandomColor)
    }
}
