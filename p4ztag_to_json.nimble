# Package

version       = "0.4.0"
author        = "Kaushal Modi"
description   = "Convert Helix Version Control / Perforce (p4) -ztag output to JSON"
license       = "MIT"
srcDir        = "src"
bin           = @["p4ztag_to_json"]

# Dependencies

requires "nim >= 0.19.9", "regex >= 0.11.0"
