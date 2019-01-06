#Include base.ahk

; Pixel coordinates for various points on screen.
replayButtonX := A_ScreenWidth  * 0.85
replayButtonY := A_ScreenHeight * 0.75
perfGraphX    := A_ScreenWidth  * 0.40
perfGraphY    := A_ScreenHeight * 0.85

; Arguments are the .osr file path, and the replay length in seconds.
; osr := A_Args[1]
osr := "replay.osr"
length := A_Args[2] + 0

; Load the skin and replay. We have to do this in a weird way because reloading the skin
; from the replay screen only queues a reload. So instead, make sure osu! is running, then
; reload the skin, then load the replay.
RunOsu()
Sleep, 5000
ReloadSkin()
RunOsu(osr)
Sleep, 2000

; Place the mouse over the replay start button.
MouseMove, %replayButtonX%, %replayButtonY%

; Start recording, wait a bit, then start the replay.
StartRecording()
Sleep, 2000
MouseClick

; Press space bar a few times to skip any intro.
Loop, 5 {
    Send, {Space}
    Sleep, 500
}

; Move the mouse to the performance graph for when the replay finishes.
MouseMove, %perfGraphX%, %perfGraphX%

; Wait for the replay to end.
Sleep, %length% * 1000

; Wait for some time on what should be the results screen, then escape, then wait some
; more, then stop recording.
; Most of the time, this will spend some time on the results screen, then on the song
; select screen. However, for maps with long outros, we might not get to the results
; screen until we press escape.
; It's much better to wait around for too long than not long enough, since the video
; can be trimmed later.
; TODO: We could try polling the screen for an image from the results screen.
Sleep, 15000
Send, {Esc}
Sleep, 15000
StopRecording()
