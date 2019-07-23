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
    if existsDir(tmpDir):
      removeDir(tmpDir)   # Remove the old tmp/ directory if it exists
    createDir(tmpDir)
    actualJsonFile.writeFile(actualJson)
    discard execCmd(diffCmd & refJsonFile & " " & actualJsonFile)
  check actualJson == refJson

suite "ztag to json":

  test "case where no valid ztag record is present (like when p4 sync doesn't have anything to update)":
    doCheck("no_valid_record")

  test "basic":
    doCheck("basic")

  test "check that a new record is created after a blank line":
    doCheck("newline_record_break")

  test "check a new record is created after desc key if the next key is at the same or lower nested index value":
    doCheck("desc_as_last_key_in_record")

  test "check that a new record is *not* created after a blank line after desc if next key is at a higher nested index":
    doCheck("blank_line_after_desc")

  test "check nested record boundaries in a record are detected even when they don't separate by a blank line":
    doCheck("nested_records")

  test "multi-line desc fields":
    doCheck("multi_line_desc")

  test "consecutive records with same field names but different values":
    doCheck("consecutive_records_same_fields")

  test "basic test for one-level nesting":
    doCheck("one_level_nesting")

  test "test for two-level nesting":
    doCheck("two_level_nesting")