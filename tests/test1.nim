import std/[unittest, os, osproc]
import p4ztag_to_json

const
  cwd = currentSourcePath.parentDir()
  tmpDir = cwd / "tmp"
  diffCmd = "git --no-pager diff -w --color-moved=dimmed-zebra --no-index -- "

template doCheck(name: string) =
  let
    ztagFile = cwd / (name & ".ztag")
    refJsonFile = cwd / (name & ".ref.json")
    refJson = readFile(refJsonFile)
    actualJson = readFile(ztagFile).ztagStringToJson()
    actualJsonFile = tmpDir / (name & ".actual.json")
  if actualJson != refJson:
    if not existsDir(tmpDir):
      createDir(tmpDir)
    actualJsonFile.writeFile(actualJson)
    discard execCmd(diffCmd & refJsonFile & " " & actualJsonFile)
  check actualJson == refJson

suite "ztag to json":

  test "basic":
    doCheck("basic")

  test "check that a new record is created after a blank line":
    doCheck("newline_record_break")

  test "check that a new record is *not* created after a blank line after desc":
    doCheck("blank_line_after_desc")
