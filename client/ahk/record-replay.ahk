#Include base.ahk

; Arguments are the .osk skin path, the .osr file path, and the replay length in ms.
osk := A_Args[1]
osr := A_Args[2]
length := A_Args[3] + 0

; Load the skin and replay. The skin must come before the replay, because loading a skin
; takes us away from the replay screen.
EnsureOsuStarted()
Run, %osk%
Sleep, 10000
Run, %osr%
Sleep, 10000
WinActivate, osu!
Sleep, 10000

; Place the mouse over the replay start button.
MouseMove, %replayButtonX%, %replayButtonY%
Sleep, 1000

; Start recording, wait a bit, then start the replay.
StartRecording()
Sleep, 3000
MouseClick

; Skip any intro.
MashSpace()

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

; Skip any outro.
MashSpace()

; Wait for some time on the results screen.
Sleep, 7500
StopRecording()

; Wait for encoding and stuff.
Sleep, 10000
