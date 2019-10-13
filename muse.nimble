# Package

version       = "0.4.0"
author        = "jiro4989"
description   = "The command and library to select multiple elements on terminal."
license       = "MIT"
srcDir        = "src"
installExt    = @["nim"]
bin           = @["muse"]
binDir        = "bin"


# Dependencies

requires "nim >= 1.0.0"
requires "illwill >= 0.1.0"
requires "cligen >= 0.9.32"

import strformat

task ci, "Run CI":
  exec "nim -v"
  exec "nimble -v"
  exec "nimble install -Y"
  exec "nimble test -Y"
  exec "nimble build -d:release -Y"
  for b in bin:
    exec &"./bin/{b} -h"
    # exec &"./bin/{b} -v"
