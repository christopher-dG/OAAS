#NoEnv
SendMode, Input
SetWorkingDir, %A_ScriptDir%

; Run osu! with an optional argument.
RunOsu(arg := "") {
    SplitPath, A_ScriptDir,, osuDir
    cmd := osuDir . "`\osu!.exe " . arg
    Run, %cmd%
}

; Start recording with OBS.
StartRecording() {
    Send, ^+!o
}

; Stop recording with OBS.
StopRecording() {
    Send, ^+!p
}

; Reload the current skin.
ReloadSkin() {
    WinActivate, osu!
    Send, {Ctrl down}{Alt down}{Shift down}{s down}
    Sleep, 100
    Send, {Ctrl up}{Alt up}{Shift up}{s up}
}

; Get the ahk_class of the osu! window.
OsuAhkClass() {
    WinGetClass, class, osu!.exe
    Return, "ahk_class" . class
}
