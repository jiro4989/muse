import illwill
import os, strutils, strformat, osproc, json
from sequtils import mapIt

const
  appName = "muse"
  confDir = getConfigDir() / appName
  cmdsFile = confDir / "commands.json"
  version = """muse version 0.2.0
Copyright (c) 2019 jiro4989
Released under the MIT License.
https://github.com/jiro4989/muse"""

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
    let exitCode = execShellCmd(cmd)
    status += exitCode
  quit(status)


var pos: int
var cmdPoses: seq[int]

proc draw(tb: var TerminalBuffer, datas: seq[string]) =
  # 選択候補のリストを表示
  for i, data in datas:
    let mark =
      if i in cmdPoses: "* "
      else: "  "
    let data2 = mark & data

    tb.resetAttributes()
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


proc subCommandExec(): int =
  if not existsDir(confDir):
    createDir(confDir)
    let cmds = %* ["echo muse test", "echo muse test2"]
    writeFile(cmdsFile, $cmds)

  if not existsFile(cmdsFile):
    stderr.writeLine("Please set commands to " & cmdsFile)
    return 1

  illwillInit(fullscreen=true)
  setControlCHook(exitProc)
  hideCursor()

  let datas = readFile(cmdsFile).parseJson.to(seq[string])

  # 4. This is how the main event loop typically looks like: we keep polling for
  # user input (keypress events), do something based on the input, modify the
  # contents of the terminal buffer (if necessary), and then display the new
  # frame.
  while true:
    # 2. We will construct the next frame to be displayed in this buffer and then
    # just instruct the library to display its contents to the actual terminal
    # (double buffering is enabled by default; only the differences from the
    # previous frame will be actually printed to the terminal).
    var tb = newTerminalBuffer(terminalWidth(), terminalHeight())

    # 3. Display some simple static UI that doesn't change from frame to frame.
    tb.setForegroundColor(fgWhite, true)
    tb.drawRect(0, 0, terminalWidth()-2, terminalHeight()-2)
    tb.write(2, 1, "J: Cursor down | K: Cursor up | C: Clear | Q: Exit | Space: Select | Enter: Execute")
    tb.drawHorizLine(1, terminalWidth()-3, 2, doubleStyle=true)
    tb.drawHorizLine(1, terminalWidth()-3, int(terminalHeight()/2), doubleStyle=true)

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
    tb.draw(datas)

    tb.display()
    sleep(20)

proc subCommandEdit(): int =
  execShellCmd(&"$EDITOR {cmdsFile}")

proc subCommandAdd(args: seq[string]): int =
  if args.len < 1:
    stderr.writeLine("Must need 1 argument.")
    return 1

  let cmd = args.join(" ")
  var cmds = readFile(cmdsFile).parseJson().to(seq[string])
  cmds.add(cmd)
  let obj = %* cmds
  writeFile(cmdsFile, obj.pretty())

when isMainModule:
  import cligen
  dispatchMulti(
    [subCommandExec, cmdName = "exec"],
    [subCommandEdit, cmdName = "edit"],
    [subCommandAdd, cmdName = "add"],
    )

