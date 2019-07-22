## The ``p4ztag_to_json`` module converts the Perforce P4 "Ztag" format to JSON.
##
## References
## ==========
## * `Helix Core P4 Command Reference<https://www.perforce.com/manuals/cmdref/Content/CmdRef/Commands%20by%20Functional%20Area.html>`_
## * `Fun with Formatting - Perforce Blog<https://www.perforce.com/blog/fun-formatting>`_

import std/[os, json, strformat]
import std/strutils except replace
import regex

const
  ztagPrefix* = "... "

proc addJsonNodeMaybe(jArr, jElem: var JsonNode) =
  if jElem.len > 0:
    jArr.add(jElem)   # Empty line in ztag marks the end of one record
    jElem = parseJson("{}") # Reset jElem to be an empty node

proc addNestedKeyMaybe(key: string; jValue, jElem: JsonNode): JsonNode =
  var
    m: RegexMatch
  if key.match(re"^(\D+)(\d+)(,(\d+))*$", m):
    let
      nestedKey = key[m.group(0)[0]]        # "key0" -> "key", "key0,1" -> "key"
      nestedId = key[m.group(1)[0]]         # "key0" -> "0"  , "key0,1" -> "0"
      nestedGroupKey = "nested" & nestedId

    # echo &"nested key = {nestedKey} | nestedId = {nestedId}"
    # echo &"dbg0: nestedGroupKey = {nestedGroupKey}"
    # echo &"grp0: {m.group(0)}"
    # echo &"dbg1: {key[m.group(0)[0]]}"
    # echo &"grp1: {m.group(1)}"
    # echo &"dbg2: {key[m.group(1)[0]]}"
    # echo &"grp2: {m.group(2)}"
    # echo &"dbg: key={key} | count={m.groupsCount}"

    if not jElem.hasKey("nested"):
      jElem["nested"] = parseJson("[]")
    if not jElem["nested"].contains(%* nestedGroupKey):
      jElem["nested"].add(%* nestedGroupKey)
    if not jElem.hasKey(nestedGroupKey):
      jElem[nestedGroupKey] = parseJson("{}")

    let
      nestedId2 = if m.group(3).len > 0:    # "key0" -> ""   , "key0,1" -> "1"
                    key[m.group(3)[0]]
                  else:
                    ""
    # if m.group(3).len > 0:
    #   echo &"dbg3: {key[m.group(3)[0]]}"
    if nestedId2 != "":
      jElem[nestedGroupKey] = addNestedKeyMaybe(nestedKey & nestedId2, jValue, jElem[nestedGroupKey])
    else:
      jElem[nestedGroupKey][nestedKey] = jValue
  else:
    jElem[key] = jValue
  return jElem

proc convertZtagLineToJson(line: string; jElem, jArr: var JsonNode; payloadStarted: var bool) =
  # echo line & $payloadStarted
  if line.startsWith(ztagPrefix):
    let
      splits = line[ztagPrefix.len .. ^1].split(' ', maxsplit=1)
      key = splits[0]
      value = splits[1]
      valueJNode = %* value

    if payloadStarted:
      jArr.addJsonNodeMaybe(jElem)
      payloadStarted = false

    jElem = addNestedKeyMaybe(key, valueJNode, jElem)
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
  let
    numFiles = paramCount()
    files = commandLineParams()
  for n in 0 ..< numFiles:
    ztagFileToJson(files[n])
