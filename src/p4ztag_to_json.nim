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
  ztagCommentPrefix* = "#... "

type
  KeyId = tuple
    key: string
    id: int
    nestedGroupKey: string
    id2: int
    nestedGroupKey2: string
  MetaData = object
    lineNum: int
    prevKeyid: KeyId
    lastSeenKey: string
    startNewElemMaybe: bool

proc getKeyId(key: string): KeyId =
  const
    nestedPrefix = "nested"
  var
    m: RegexMatch
  if key.match(re"^(\D+)(\d+)(,(\d+))*$", m):
    #               ^^^  ^^^-- m.group(1) -- result.id
    #                |
    #                +-------- m.group(0) -- result.key
    result.key = key[m.group(0)[0]]           # "key0" -> "key", "key0,1" -> "key"
    result.id = key[m.group(1)[0]].parseInt() # "key0" -> 0  , "key0,1" -> 0
    result.nestedGroupKey = nestedPrefix & $result.id

    result.id2 = if m.group(3).len > 0:       # "key0" -> -1 , "key0,1" -> 1
                   key[m.group(3)[0]].parseInt()
                 else:
                   -1
    if result.id2 >= 0:
      result.nestedGroupKey2 = nestedPrefix & $result.id2

    when defined(debug):
    # echo &"grp0: {m.group(0)}"
    # echo &"dbg1: {key[m.group(0)[0]]}"
    # echo &"grp1: {m.group(1)}"
    # echo &"dbg2: {key[m.group(1)[0]]}"
    # echo &"grp2: {m.group(2)}"
    # echo &"dbg: key={key} | count={m.groupsCount}"
      if m.group(3).len > 0:
        echo &"dbg3: {key[m.group(3)[0]]}"
      echo &"[getKeyId] result = {result}"
  else:
    result = (key, -1, "", -1, "")

proc updateJArr(jArr, jElem: var JsonNode; meta: var MetaData) =
  ## Add ``jElem`` to JSON array ``jArr``.
  ## Do this only if ``jElem`` is non-empty.
  ## Reset ``jElem`` to an empty node after that.
  if jElem.len > 0:
    jArr.add(jElem)  # Empty line in ztag marks the end of one record.
    jElem = %* {} # Reset jElem to be an empty node now.

  # Now that a new JSON element was added if non-empty, clear the
  # startNewElemMaybe flag.
  meta.startNewElemMaybe = false

proc updateJElem(keyid: KeyId; jValue, jElem: JsonNode; meta: var MetaData): JsonNode =
  ## Assign value to a key directly in ``jElem`` or to a nested
  ## element in that.
  if keyid.id >= 0:
    if not jElem.hasKey("nested"):
      jElem["nested"] = parseJson("[]")
    if not jElem["nested"].contains(%* keyid.nestedGroupKey):
      jElem["nested"].add(%* keyid.nestedGroupKey)
    if not jElem.hasKey(keyid.nestedGroupKey):
      jElem[keyid.nestedGroupKey] = parseJson("{}")

    if keyid.id2 >= 0:
      let
        keyid2 = getKeyId(keyid.key & $keyid.id2)
      jElem[keyid.nestedGroupKey] = updateJElem(keyid2, jValue, jElem[keyid.nestedGroupKey], meta)
    else:
      jElem[keyid.nestedGroupKey][keyid.key] = jValue
  else:
    jElem[keyid.key] = jValue
  return jElem

proc convertZtagLineToJson(line: string; jElem, jArr: var JsonNode; meta: var MetaData) =
  ## Convert the single ztag line to JSON object.
  ## Data is first set in single JSON elements (``jElem``) and then that
  ## element is added to a JSON array (``jArr``).
  when defined(debug):
    echo &"line.len = {line.len}, meta = {meta}"
  if line.startsWith(ztagCommentPrefix):
    discard # Just ignore all lines beginning with the ztagCommentPrefix
  elif line.startsWith(ztagPrefix):
    let
      splits = line[ztagPrefix.len .. ^1].split(' ', maxsplit=1)
      key = splits[0]
      keyid = getKeyId(key)
      value = splits[1]
      valueJNode = %* value

    when defined(debug):
      echo &"current line keyid = {keyid}"

    if meta.startNewElemMaybe and
       meta.prevKeyid.key == "" and
       keyid.id <= meta.prevKeyid.id and
       (keyid.id == meta.prevKeyid.id and keyid.id2 <= meta.prevKeyid.id2):
      jArr.updateJArr(jElem, meta)

    jElem = updateJElem(keyid, valueJNode, jElem, meta)
    meta.prevKeyid = keyid
    meta.lastSeenKey = keyid.key
  else:
    meta.startNewElemMaybe = true
    if line.len == 0 and # blank line following a non-blank line
       meta.prevKeyid.key != "":
      discard
    elif meta.lastSeenKey != "":
      when defined(debug):
        echo "jElem = ", jElem.pretty
      if meta.prevKeyid.id >= 0:
        if meta.prevKeyid.id2 >= 0:
          let
            existingVal = jElem[meta.prevKeyid.nestedGroupKey][meta.prevKeyid.nestedGroupKey2][meta.lastSeenKey].getStr()
          jElem[meta.prevKeyid.nestedGroupKey][meta.prevKeyid.nestedGroupKey2][meta.lastSeenKey] = %* (existingVal & "\n" & line)
        else:
          let
            existingVal = jElem[meta.prevKeyid.nestedGroupKey][meta.lastSeenKey].getStr()
          jElem[meta.prevKeyid.nestedGroupKey][meta.lastSeenKey] = %* (existingVal & "\n" & line)
      else:
        let
          existingVal = jElem[meta.lastSeenKey].getStr()
        jElem[meta.lastSeenKey] = %* (existingVal & "\n" & line)
    meta.prevKeyid.key = ""

template populateJArr(iter: untyped) {.dirty.} =
  var
    jArr = newJArray() # Initialize JsonNode array
    jElem = newJObject() # Initialize JsonNode array element/object
    meta = MetaData(lineNum: 1,
                    prevKeyid: ("", -1, "", -1, ""),
                    startNewElemMaybe: false)

  for line in iter:
    when defined(debug):
      echo &"\n[{meta.lineNum}] {line}"
    convertZtagLineToJson(line, jElem, jArr, meta)
    meta.lineNum += 1
  jArr.updateJArr(jElem, meta)

proc ztagFileToJson*(filename: string) =
  ## Read input ztag file and convert/write to a JSON file.
  populateJArr(filename.lines)
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
  populateJArr(ztag.splitLines())
  return jArr.pretty()

when isMainModule:
  let
    numFiles = paramCount()
    files = commandLineParams()
  for n in 0 ..< numFiles:
    ztagFileToJson(files[n])
