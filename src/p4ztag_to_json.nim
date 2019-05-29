## The ``p4ztag_to_json`` module converts the Perforce P4 "Ztag" format to JSON.
##
## References
## ==========
## * `Helix Core P4 Command Reference<https://www.perforce.com/manuals/cmdref/Content/CmdRef/Commands%20by%20Functional%20Area.html>`_
## * `Fun with Formatting - Perforce Blog<https://www.perforce.com/blog/fun-formatting>`_

import std/[os, json]
import std/strutils except replace
import regex

const
  ztagPrefix* = "... "

proc addJsonNodeMaybe(jArr, jElem: var JsonNode) =
  if jElem.len > 0:
    jArr.add(jElem)   # Empty line in ztag marks the end of one record
    jElem = parseJson("{}") # Reset jElem to be an empty node

proc convertZtagLineToJson(line: string; jElem, jArr: var JsonNode; payloadStarted: var bool) =
  # echo line & $payloadStarted
  if line.startsWith(ztagPrefix):
    let
      splits = line[ztagPrefix.len .. ^1].split(' ', maxsplit=1)
      value = splits[1]
      valueJNode = %* value
    var
      key = splits[0]
    if payloadStarted:
      jArr.addJsonNodeMaybe(jElem)
      payloadStarted = false
    if key.contains(','):
      let
        keyParts = key.split(',')
      doAssert keyParts.len == 2 # We don't support keys with more than one comma right now
      let
        keySub = keyParts[0].replace(re"\d+$", "") # Replace keys like "user0" to "user"
      key = "nested" & keyParts[1]
      let
        keyJNode = %* key
      if not jElem.hasKey("nested"):
        jElem["nested"] = parseJson("[]")
      if not jElem["nested"].contains(keyJNode):
        jElem["nested"].add(keyJNode)
      if not jElem.hasKey(key):
        jElem[key] = parseJson("{}")
      jElem[key][keySub] = valueJNode
    else:
      key = key.replace(re"\d+$", "") # Replace keys like "user0" to "user"
      jElem[key] = valueJNode
  else:
    payloadStarted = true
    if not jElem.hasKey("payload"):
      if line.len > 0:
        jElem["payload"] = %* line
    else:
      let
        existingPayload = jElem["payload"].getStr()
      jElem["payload"] = %* (existingPayload & "\n" & line)

proc ztagFileToJson*(filename: string) =
  ## Read input ztag file and convert/write to a JSON file.
  var
    jArr = parseJson("[]")      # Initialize JsonNode array
    jElem = parseJson("{}")     # Initialize JsonNode array element
    payloadStarted = false

  for line in filename.lines:
    convertZtagLineToJson(line, jElem, jArr, payloadStarted)
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
    payloadStarted = false

  for line in ztag.splitLines():
    convertZtagLineToJson(line, jElem, jArr, payloadStarted)
  jArr.addJsonNodeMaybe(jElem)

  return jArr.pretty()

when isMainModule:
  const
    cwd = currentSourcePath.parentDir()
    sampleZtagFile = cwd / ".." / "tests" / "sample.ztag"
  ztagFileToJson(sampleZtagFile)
  echo readFile(sampleZtagFile).ztagStringToJson()
