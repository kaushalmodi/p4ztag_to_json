import std/[unittest, os]
import p4ztag_to_json

const
  cwd = currentSourcePath.parentDir()

proc getZtagFileAndRef(name: string): tuple[ztagFile: string, refJson: string] =
  let
    ztagFile = cwd / (name & ".ztag")
    refJsonFile = cwd / (name & ".ref.json")
    refJson = readFile(refJsonFile)
  return (ztagFile, refJson)

template doCheck(name: string) =
  let
    (z, j) = getZtagFileAndRef(name)
  check readFile(z).ztagStringToJson() == j

suite "ztag to json":

  test "basic":
    doCheck("basic")

  test "check that a new record is created after a blank line":
    doCheck("newline_record_break")

  test "check that a new record is *not* created after a blank line after desc":
    doCheck("blank_line_after_desc")
