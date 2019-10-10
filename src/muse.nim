import illwill
import os, strutils, strformat, osproc, json
from sequtils import mapIt

const
  appName = "muse"
  confDir = getConfigDir() / appName
  cmdsFile = confDir / "commands.json"

if not existsDir(confDir):
  createDir(confDir)
  let cmds = %* ["echo muse test", "echo muse test2"]
  writeFile(cmdsFile, $cmds)

if not existsFile(cmdsFile):
  stderr.writeLine("Please set commands to " & cmdsFile)
  quit(1)

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
    echo "$ " & cmd
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

let datas = readFile(cmdsFile).parseJson.to(seq[string])

# 3. Display some simple static UI that doesn't change from frame to frame.
tb.setForegroundColor(fgWhite, true)
tb.drawRect(0, 0, terminalWidth()-2, terminalHeight()-2)
tb.write(2, 1, "J: Cursor down, K: Cursor up, C: Clear, Q: Exit, Space: Select, Enter: Execute")
tb.drawHorizLine(1, terminalWidth()-3, 2, doubleStyle=true)
tb.drawHorizLine(1, terminalWidth()-3, int(terminalHeight()/2), doubleStyle=true)

var pos: int
var cmdPoses: seq[int]

proc draw =
  # 選択候補のリストを表示
  for i, data in datas:
    let mark =
      if i in cmdPoses: "* "
      else: "  "
    let data2 = mark & data

    if i == pos:
      tb.setForegroundColor(fgBlack, true)
      tb.setBackgroundColor(bgGreen)
      tb.write(2, i+3, data2)
      tb.resetAttributes()
    else:
      tb.write(2, i+3, data2)

  # 実行するコマンドのリストを表示
  for i, p in cmdPoses:
    let data = datas[p]
    let data2 = $i & " " & data
    tb.write(2, int(terminalHeight() / 2) + i + 1, data2)

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

