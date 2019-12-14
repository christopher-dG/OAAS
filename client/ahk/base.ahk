#NoEnv
SendMode, Input
SetWorkingDir, %A_ScriptDir%
CoordMode, Mouse

FileRead, txt, coords.txt
nums := StrSplit(txt, " ")
replayButtonX := nums[1]
replayButtonY := nums[2]
perfGraphX := nums[3]
perfGraphY := nums[4]

; Start recording with OBS.
StartRecording() {
    Send, {Ctrl down}{Alt down}{Shift down}{o down}
    Sleep, 100
    Send, {Ctrl up}{Alt up}{Shift up}{o up}
}

; Stop recording with OBS.
StopRecording() {
    Send, {Ctrl down}{Alt down}{Shift down}{p down}
    Sleep, 100
    Send, {Ctrl up}{Alt up}{Shift up}{p up}
}

; Reload the current skin.
ReloadSkin() {
    EnsureOsuStarted()
    WinActivate, osu!
    Send, {Ctrl down}{Alt down}{Shift down}{s down}
    Sleep, 100
    Send, {Ctrl up}{Alt up}{Shift up}{s up}
}

; Make sure that osu! is running.
EnsureOsuStarted() {
    if !WinExist("osu!") {
        SplitPath, A_ScriptDir,, osuDir
        cmd := osuDir . "`\osu!.exe "
        Run, %cmd%
        Sleep, 10000
    }
}

; Press space bar a few times to skip any intro or outro.
MashSpace() {
    Loop, 5 {
        Send, {Space down}
        Sleep, 100
        Send, {Space up}
        Sleep, 400
    }
}

; Get the ahk_class of the osu! window.
OsuAhkClass() {
    WinGetClass, class, osu!.exe
    Return, "ahk_class " . class
}
