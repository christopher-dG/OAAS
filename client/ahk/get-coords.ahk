#Include base.ahk

MsgBox,
(
  Do the following after dismissing this message box:
  1. Open osu! to a replay results screen.
  2. Hover mouse over the "start replay" button, then press "a"
  3. Hover mouse over the performance graph, then bress "b"
  A message box should appear immediately afterwards.
)

KeyWait, a, D
MouseGetPos, bX, bY

KeyWait, b, D
MouseGetPos, gX, gY

file := FileOpen("coords.txt", "w")
file.Write(Format("{:d} {:d} {:d} {:d}", bX, bY, gX, gY))

MsgBox, Done! Please ensure that "coords.txt" exists.
