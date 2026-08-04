# Package

version     = "1.0.0"
author      = "nsaspy"
description = "Async and synchronous Mastodon API client for Nim"
license     = "MIT"
srcDir      = "src"

# Dependencies

requires "nim >= 2.0.0"

task test, "Run unit tests":
  exec "nim c -r --path:src tests/test_fedi.nim"
