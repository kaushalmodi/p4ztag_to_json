import std/[unittest, os]
import p4ztag_to_json

suite "ztag to json":
  setup:
    const
      cwd = currentSourcePath.parentDir()
      sampleZtagFile = cwd / "sample.ztag"
      sampleJsonFile = cwd / "sample.json"
      refJson = """[
  {
    "depotFile": "//abc/def/ghi/TRUNK/jkl/mno/pqr.stu",
    "clientFile": "//ws:vwx:def.yz:7434600b/ghi/jkl/mno/pqr.stu",
    "rev": "7",
    "haveRev": "3",
    "action": "edit",
    "change": "568524",
    "type": "text",
    "user": "vwx",
    "client": "ws:vwx:def.yz:0680383b"
  },
  {
    "depotFile": "//abc/def/ghi/TRUNK/jkl/mno/PQR.STU",
    "clientFile": "//ws:vwx:def.yz:6824560b/ghi/jkl/mno/PQR.STU",
    "rev": "1",
    "haveRev": "6",
    "action": "edit",
    "change": "085030",
    "type": "text",
    "user": "vwx",
    "client": "ws:vwx:def.yz:8464768b"
  }
]"""

  test "ztag string to JSON":
    check readFile(sampleZtagFile).ztagStringToJson() == refJson

  test "ztag file to JSON":
    ztagFileToJson(sampleZtagFile)
    check readFile(sampleJsonFile) == refJson
    removeFile(sampleJsonFile)
