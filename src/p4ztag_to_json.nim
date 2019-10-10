## The ``p4ztag_to_json`` module converts the Perforce P4 "Ztag" format to JSON.
##
## References
## ==========
## * `Helix Core P4 Command Reference<https://www.perforce.com/manuals/cmdref/Content/CmdRef/Commands%20by%20Functional%20Area.html>`_
## * `Fun with Formatting - Perforce Blog<https://www.perforce.com/blog/fun-formatting>`_

import std/[os, json]
import std/strutils except replace
import regex
when defined(debug):
  import std/[strformat]

const
  ztagPrefix* = "... "
  ztagCommentPrefix* = "#... "
  ztagMessageKey* = "message"

type
  KeyId = object
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
    recordStartKey: string

proc getKeyId(key: string): KeyId =
  result = KeyId(key: key,
                 id: -1,
                 nestedGroupKey: "",
                 id2: -1,
                 nestedGroupKey2: "")
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
  ## Assign ``jValue`` to a key directly in ``jElem`` or to a nested
  ## element in that.
  if keyid.id == -1: # top level element
    jElem[keyid.key] = jValue
    return jElem

  # first or higher level nesting
  if not jElem.hasKey("nested"):
    jElem["nested"] = %* []
  if not jElem["nested"].contains(%* keyid.nestedGroupKey):
    jElem["nested"].add(%* keyid.nestedGroupKey)
  if not jElem.hasKey(keyid.nestedGroupKey):
    jElem[keyid.nestedGroupKey] = %* {}

  if keyid.id2 == -1: # no second-level nesting
    jElem[keyid.nestedGroupKey][keyid.key] = jValue
    return jElem

  # second or higher level nesting
  let
    keyid2 = getKeyId(keyid.key & $keyid.id2)
  jElem[keyid.nestedGroupKey] = updateJElem(keyid2, jValue, jElem[keyid.nestedGroupKey], meta)
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
    var
      key: string
      valueStr: string
      valueJNode: JsonNode
    let
      lineMinusDots = line[ztagPrefix.len .. ^1]
      splits = lineMinusDots.split(' ', maxsplit=1)
    if splits[0].startsWith("/"):
      key = ztagMessageKey
      if jElem.hasKey(ztagMessageKey):
        valueStr = jElem[ztagMessageKey].getStr() & "\n" & lineMinusDots
      else:
        valueStr = lineMinusDots
      valueJNode = %* valueStr
    else:
      key = splits[0]
      # Force uncapitalize the keys #consistency
      key[0] = key[0].toLowerAscii()
      if splits.len == 2: # "... key valueStr"
        valueStr = splits[1]
        valueJNode = %* valueStr
      else: # splits.len == 1, "... boolean_key"
        valueJNode = %* true

    let
      keyid = getKeyId(key)

    if meta.recordStartKey == "":
      # This is evaluated only once, when the very first key is parsed.
      meta.recordStartKey = key

    when defined(debug):
      echo &"current line keyid = {keyid}"

    if meta.startNewElemMaybe and
       meta.prevKeyid.key == "" and
       meta.lastSeenKey != ztagMessageKey and
       ((keyid.key == meta.recordStartKey) or
        (keyid.id, keyid.id2) < (meta.prevKeyid.id, meta.prevKeyid.id2)):
      when defined(debug):
        echo &"\nending the current json element; `{keyid.key}' key will be added to the next one"
      jArr.updateJArr(jElem, meta)

    jElem = updateJElem(keyid, valueJNode, jElem, meta)
    meta.prevKeyid = keyid
    meta.lastSeenKey = keyid.key
  elif meta.lastSeenKey == "" and # before the first ztag key got parsed
       line.strip().len > 0:
    jElem[ztagMessageKey] = %* line
    meta.lastSeenKey = ztagMessageKey
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
                    prevKeyid: KeyId(key: "",
                                     id: -1,
                                     nestedGroupKey: "",
                                     id2: -1,
                                     nestedGroupKey2: ""),
                    startNewElemMaybe: false,
                    recordStartKey: "")

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

proc ztagStringToJson*(ztagStr: string): string =
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
  populateJArr(ztagStr.strip().splitLines())
  return jArr.pretty()

when isMainModule:
  import std/[terminal]

  # Example use:
  #   > echo "<some ztag data>" | p4ztag_to_json
  #   # prints the converted JSON to the stdout
  if not isatty(stdin):
    let
      stdinData = readAll(stdin)
    echo stdinData.ztagStringToJson()
  else:
    let
      numFiles = paramCount()
      files = commandLineParams()
    for n in 0 ..< numFiles:
      ztagFileToJson(files[n])
