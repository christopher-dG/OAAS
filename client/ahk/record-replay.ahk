#Include base.ahk

; Pixel coordinates for various points on screen.
replayButtonX := Round(A_ScreenWidth  * 0.85)
replayButtonY := Round(A_ScreenHeight * 0.75)
perfGraphX    := Round(A_ScreenWidth  * 0.40)
perfGraphY    := Round(A_ScreenHeight * 0.85)

; Arguments are the .osk skin path, the .osr file path, and the replay length in seconds.
osk := A_Args[1]
osr := A_Args[2]
length := Round(A_Args[3] * 1000)

; Load the skin and replay. The skin must come before the replay, because loading a skin
; takes us away from the replay screen.
EnsureOsuStarted()
Run, %osk%
Sleep, 10000
Run, %osr%
Sleep, 10000

; Place the mouse over the replay start button.
MouseMove, %replayButtonX%, %replayButtonY%

; Start recording, wait a bit, then start the replay.
StartRecording()
Sleep, 3000
MouseClick

; Press space bar a few times to skip any intro.
Loop, 5 {
    Send, {Space down}
    Sleep, 100
    Send, {Space up}
    Sleep, 400
}

;; Hide the leaderboard.
Send, {Tab down}
Sleep, 100
Send, {Tab up}

; Move the mouse to the performance graph for when the replay finishes.
MouseMove, %perfGraphX%, %perfGraphY%

; Wait for the replay to end.
Sleep, %length%

; Move the mouse again, just in case it got jostled.
MouseMove, %perfGraphX%, %perfGraphY%

; Wait for some time on what should be the results screen, then escape, then wait some
; more, then stop recording.
; Most of the time, this will spend some time on the results screen, then on the song
; select screen. However, for maps with long outros, we might not get to the results
; screen until we press escape.
; It's much better to wait around for too long than not long enough, since the video
; can be trimmed later.
; TODO: We could try polling the screen for an image from the results screen.
Sleep, 15000
Send, {Esc down}
Sleep, 100
Send, {Esc up}
Sleep, 15000
StopRecording()
