import illwill
import os, strutils, strformat

# 1. Initialise terminal in fullscreen mode and make sure we restore the state
# of the terminal state when exiting.
proc exitProc() {.noconv.} =
  illwillDeinit()
  showCursor()
  quit(0)

illwillInit(fullscreen=true)
setControlCHook(exitProc)
hideCursor()

# 2. We will construct the next frame to be displayed in this buffer and then
# just instruct the library to display its contents to the actual terminal
# (double buffering is enabled by default; only the differences from the
# previous frame will be actually printed to the terminal).
var tb = newTerminalBuffer(terminalWidth(), terminalHeight())

let datas = @[
  "/var/log/syslog",
  "/var/log/access_log",
  "/var/log/app.log",
  "/var/log/err.log",
  ]

# 3. Display some simple static UI that doesn't change from frame to frame.
tb.setForegroundColor(fgBlack, true)
tb.drawRect(0, 0, 40, 5+datas.len)
tb.drawHorizLine(2, 38, 3, doubleStyle=true)

var pos: int

proc draw =
  for i, data in datas:
    if i == pos:
      tb.write(2, Natural(i+2), "* " & data)
    else:
      tb.write(2, Natural(i+2), "  " & data)

# 4. This is how the main event loop typically looks like: we keep polling for
# user input (keypress events), do something based on the input, modify the
# contents of the terminal buffer (if necessary), and then display the new
# frame.
while true:
  var key = getKey()
  case key
  of Key.None: discard
  of Key.Escape, Key.Q: exitProc()
  of Key.J:
    inc(pos)
    if datas.len <= pos:
      pos = 0
  of Key.K:
    dec(pos)
    if pos < 0:
      pos = datas.len - 1
  else: discard
  draw()

  tb.display()
  sleep(20)
