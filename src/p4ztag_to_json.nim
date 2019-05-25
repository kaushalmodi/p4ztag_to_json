## The ``p4ztag_to_json`` module converts the Perforce P4 "Ztag" format to JSON.
##
## References
## ==========
## * `Helix Core P4 Command Reference<https://www.perforce.com/manuals/cmdref/Content/CmdRef/Commands%20by%20Functional%20Area.html>`_
## * `Fun with Formatting - Perforce Blog<https://www.perforce.com/blog/fun-formatting>`_

import std/[strutils, os, json]

const
  ztagPrefix* = "... "

proc addJsonNodeMaybe(jArr, jElem: var JsonNode) =
  if jElem.len > 0:
    jArr.add(jElem)   # Empty line in ztag marks the end of one record
    jElem = parseJson("{}") # Reset jElem to be an empty node

proc convertZtagLineToJson(line: string; jElem, jArr: var JsonNode) =
  # echo line
  if line.startsWith(ztagPrefix):
    let
      splits = line[ztagPrefix.len .. ^1].split(' ', maxsplit=2)
      key = splits[0]
      value = splits[1]
    jElem[key] = %* value
  else:
    jArr.addJsonNodeMaybe(jElem)

proc ztagFileToJson*(filename: string) =
  ## Read input ztag file and convert/write to a JSON file.
  var
    jArr = parseJson("[]")      # Initialize JsonNode array
    jElem = parseJson("{}")     # Initialize JsonNode array element

  for line in filename.lines:
    convertZtagLineToJson(line, jElem, jArr)
  jArr.addJsonNodeMaybe(jElem)
  # echo jArr.pretty()

  changeFileExt(filename, "json").writeFile(jArr.pretty)

proc ztagStringToJson*(ztag: string): string =
  ## Convert input ztag string to JSON.
  ##
  runnableExamples:
    let
      ztagString = """... abc d/e/f
... ghi 1.2.3

... abc j:k:l
... mno 456.789"""
      jsonString = """[
  {
    "abc": "d/e/f",
    "ghi": "1.2.3"
  },
  {
    "abc": "j:k:l",
    "mno": "456.789"
  }
]"""
    doAssert ztagString.ztagStringToJson() == jsonString
  ##
  var
    jArr = parseJson("[]")      # Initialize JsonNode array
    jElem = parseJson("{}")     # Initialize JsonNode array element

  for line in ztag.splitLines():
    convertZtagLineToJson(line, jElem, jArr)
  jArr.addJsonNodeMaybe(jElem)

  return jArr.pretty()

when isMainModule:
  const
    cwd = currentSourcePath.parentDir()
    sampleZtagFile = cwd / ".." / "tests" / "sample.ztag"
  ztagFileToJson(sampleZtagFile)
  echo readFile(sampleZtagFile).ztagStringToJson()
