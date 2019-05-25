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
    "client": "ws:vwx:def.yz:0680383b",
    "payload": "payload of first record1\n\npayload of first record2\npayload of first record3"
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
    "client": "ws:vwx:def.yz:8464768b",
    "payload": "payload of second record1\n\npayload of second record2\npayload of second record3\n"
  },
  {
    "abc": "d/e/f",
    "ghi": "1.2.3"
  },
  {
    "abc": "j:k:l",
    "mno": "456.789"
  }
]"""

  test "ztag string to JSON":
    check readFile(sampleZtagFile).ztagStringToJson() == refJson

  test "ztag file to JSON":
    ztagFileToJson(sampleZtagFile)
    check readFile(sampleJsonFile) == refJson
    removeFile(sampleJsonFile)
