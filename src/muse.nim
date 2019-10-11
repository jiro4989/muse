import illwill
import os, strutils, strformat, osproc, json
from sequtils import mapIt

const
  appName = "muse"
  confDir = getConfigDir() / appName
  cmdsFile = confDir / "commands.json"
  version = """muse version 0.4.0
Copyright (c) 2019 jiro4989
Released under the MIT License.
https://github.com/jiro4989/muse"""
  keyHelps = [
    "J: Cursor down | K: Cursor up | H: Left tab | L: Right tab",
    "C: Clear | Q: Exit | Space: Select | Enter: Execute",
  ]

type
  CommandList = object
    name: string
    commands: seq[string]

proc exitProc() {.noconv.} =
  ## 終了処理
  illwillDeinit()
  showCursor()
  quit(0)

proc execCommands(cmds: seq[string]) {.noconv.} =
  ## 終了処理を行うが、最後にコマンドを実行する
  illwillDeinit()
  showCursor()
  var status: int
  for cmd in cmds:
    echo "$ " & cmd
    let exitCode = execShellCmd(cmd)
    status += exitCode
  quit(status)

proc drawTabArea(tb: var TerminalBuffer, y, tabIndex: int, datas: seq[CommandList]) =
  var tabs: seq[string]
  for i, page in datas:
    let name = page.name
    let tab =
      if i == tabIndex:
        &"[ * {name} ]"
      else:
        &"[   {name} ]"
    tabs.add(tab)
  tb.write(2, y, tabs.join("-"))

proc drawSelectionArea(tb: var TerminalBuffer, y: int, pos: int, datas: seq[string]) =
  # 選択候補のリストを表示
  for i, data in datas:
    let data2 = data

    if i == pos:
      tb.setForegroundColor(fgBlack, true)
      tb.setBackgroundColor(bgGreen)
      tb.write(2, y+i, data2)
    else:
      tb.write(2, y+i, data2)
    tb.resetAttributes()

proc drawCommandStackArea(tb: var TerminalBuffer, y: int, datas: seq[string]) =
  ## 実行するコマンドのリストを表示
  for i, data in datas:
    let data2 = $(i+1) & " " & data
    tb.write(2, y+i, data2)

proc subCommandExec(): int =
  ## コマンド選択UIを起動する
  # 設定ディレクトリがなければ作成して初期データのコマンドファイルを配置
  if not existsDir(confDir):
    createDir(confDir)
    let cmds = %* [{"name":"nim", "commands":["nim --version", "nimble build", "nimble test"]}]
    writeFile(cmdsFile, $cmds)

  # コマンドファイルが存在しなければ異常終了
  if not existsFile(cmdsFile):
    stderr.writeLine("Please set commands to " & cmdsFile)
    return 1

  # コマンドファイルからコマンドの一覧を取得
  let datas = readFile(cmdsFile).parseJson.to(seq[CommandList])

  # 初期設定。とりあえずやっとく
  illwillInit(fullscreen=true)
  setControlCHook(exitProc)
  hideCursor()

  var
    pos: int              ## 現在のタブ内の選択要素のインデックス
    tabIndex: int         ## 現在のタブのインデックス
    cmdStack: seq[string] ## 選択されたコマンドのスタック

  while true:
    # 後から端末の幅が変わる場合があるため
    # 端末の幅情報はループの都度取得
    let tw = terminalWidth()
    let th = terminalHeight()

    var tb = newTerminalBuffer(tw, th)
    tb.setForegroundColor(fgWhite, true)

    # キー入力ヘルプエリアの描画
    tb.drawRect(0, 0, tw-2, th-1)
    for i, help in keyHelps:
      tb.write(2, i+1, help)

    # キーヘルプの境界線の描画
    let tabAreaY = keyHelps.len + 1
    tb.drawHorizLine(1, tw-3, tabAreaY, doubleStyle=true)

    # タブを描画
    tb.drawTabArea(tabAreaY, tabIndex, datas)

    # コマンド選択エリアとコマンドスタックの境界線の描画
    let cmdStackAreaY = int(th/2) + 2
    tb.drawHorizLine(1, tw-3, cmdStackAreaY-1, doubleStyle=true)

    tb.resetAttributes()

    # 現在のタブのコマンドリスト
    let currentCmds = datas[tabIndex].commands

    # コマンド選択エリアの描画
    tb.drawSelectionArea(tabAreaY+1, pos, currentCmds)

    # コマンドスタックの描画
    tb.drawCommandStackArea(cmdStackAreaY, cmdStack)

    # キー入力でコマンド選択位置、タブindexを更新
    # あるいはコマンドの実行など
    var key = getKey()
    case key
    of Key.None: discard
    of Key.Escape, Key.Q: exitProc()
    of Key.J:
      # Cursor down
      inc(pos)
      if currentCmds.len <= pos:
        pos = 0
    of Key.K:
      # Cursor up
      dec(pos)
      if pos < 0:
        pos = currentCmds.len - 1
    of Key.H:
      # Move left tab
      pos = 0
      dec(tabIndex)
      if tabIndex < 0:
        tabIndex = datas.len - 1
    of Key.L:
      # Move right tab
      pos = 0
      inc(tabIndex)
      if datas.len <= tabIndex:
        tabIndex = 0
    of Key.Space:
      # 現在位置のコマンドをスタックに追加
      let cmd = currentCmds[pos]
      cmdStack.add(cmd)
    of Key.C:
      # コマンドスタックを初期化
      cmdStack = @[]
    of Key.Enter:
      # コマンドを実行して終了
      execCommands(cmdStack)
    else: discard

    tb.display()
    sleep(20)

proc subCommandEdit(): int =
  ## 設定ファイルを編集する
  execShellCmd(&"$EDITOR {cmdsFile}")

when isMainModule:
  import cligen
  dispatchMulti(
    [subCommandExec, cmdName = "exec"],
    [subCommandEdit, cmdName = "edit"],
  )

