import std/[unittest, envvars, strutils, asyncdispatch]
import typesense

let
  rootkey = getEnv("TYPESENSE_KEY").strip()
  address = "0.0.0.0"

template newTypesenseClient() {.dirty.} =
  var ts = newClient(address, Port(8108), rootkey)

test "can init":
  newTypesenseClient()
  assert waitFor(ts.health())
  ts.close()

test "/keys POST":
  newTypesenseClient()
  let key = waitFor ts.keys.create("Some key")
  assert key.getActions == {tsAnyActions}

test "/keys GET":
  newTypesenseClient()
  let allkeys = waitFor ts.keys.retrieve 
  assert allkeys.len != 0

test "/keys DELETE":
  newTypesenseClient()
  waitFor ts.keys.deleteAll()
  let allkeys = waitFor ts.keys.retrieve
  assert allkeys.len == 0

test "/collections":
  newTypesenseClient()
  let collections = waitFor ts.collections.retrieve()