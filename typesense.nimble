# Package

version       = "0.1.0"
author        = "George Lemon"
description   = "Typesense API Client 👑 A fast, typo tolerant, in-memory fuzzy search engine"
license       = "MIT"
srcDir        = "src"


# Dependencies

requires "nim >= 2.0.0"
requires "jsony"

task dev, "test library":
  exec "nim c --out:./bin/typesense src/typesense.nim"