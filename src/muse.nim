import illwill
import os, strutils, strformat, osproc
from sequtils import mapIt

# 1. Initialise terminal in fullscreen mode and make sure we restore the state
# of the terminal state when exiting.
proc exitProc() {.noconv.} =
  illwillDeinit()
  showCursor()
  quit(0)

proc exitProcExec(cmds: seq[string] =  @[]) {.noconv.} =
  illwillDeinit()
  showCursor()
  var status: int
  for cmd in cmds:
    let (output, exitCode) = execCmdEx(cmd)
    stdout.write output
    status += exitCode
  quit(status)

illwillInit(fullscreen=true)
setControlCHook(exitProc)
hideCursor()

# 2. We will construct the next frame to be displayed in this buffer and then
# just instruct the library to display its contents to the actual terminal
# (double buffering is enabled by default; only the differences from the
# previous frame will be actually printed to the terminal).
var tb = newTerminalBuffer(terminalWidth(), terminalHeight())

let datas = @[
  "echo 1",
  "echo 2",
  "echo 3",
  "echo 4",
  """echo -e '\e[31m unko \e[m geri'"""
  ]

# 3. Display some simple static UI that doesn't change from frame to frame.
tb.setForegroundColor(fgWhite, true)
tb.drawRect(0, 0, 40, 5+datas.len)
tb.drawHorizLine(2, 38, 3, doubleStyle=true)

var pos: int
var cmdPoses: seq[int]

proc draw =
  for i, data in datas:
    let mark =
      if i in cmdPoses: "* "
      else: "  "
    let data2 = mark & data

    if i == pos:
      tb.setForegroundColor(fgBlack, true)
      tb.setBackgroundColor(bgGreen)
      tb.write(2, Natural(i+2), data2)
      tb.resetAttributes()
    else:
      tb.write(2, Natural(i+2), data2)

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
  of Key.Space:
    cmdPoses.add(pos)
  of Key.C:
    cmdPoses = @[]
  of Key.Enter:
    let cmds = cmdPoses.mapIt(datas[it])
    exitProcExec(cmds)
  else: discard
  draw()

  tb.display()
  sleep(20)

