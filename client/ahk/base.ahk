#NoEnv
SendMode, Input
SetWorkingDir, %A_ScriptDir%

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
        Sleep, 5000
    }
}

; Get the ahk_class of the osu! window.
OsuAhkClass() {
    WinGetClass, class, osu!.exe
    Return, "ahk_class " . class
}
