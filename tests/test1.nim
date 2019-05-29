import std/[unittest, os]
import p4ztag_to_json

suite "ztag to json":
  setup:
    const
      cwd = currentSourcePath.parentDir()
      sampleZtagFile = cwd / "sample.ztag"
      refJson = readFile(cwd / "reference.json")
      outputJsonFile = cwd / "sample.json"

  test "ztag string to JSON":
    check readFile(sampleZtagFile).ztagStringToJson() == refJson

  test "ztag file to JSON":
    ztagFileToJson(sampleZtagFile)
    check readFile(outputJsonFile) == refJson
    removeFile(outputJsonFile)
