import std/[unittest, envvars, strutils, asyncdispatch]
import typesense

let
  rootkey = getEnv("TYPESENSE_KEY").strip()
  address = "0.0.0.0"
  # rootkey = "bV9ZXnOpBFc1CPivLCvZ74OuutTniiei44lyziQqrFgACsZy"
  # address = "10.242.195.202" # 0.0.0.0

echo rootkey

template newTypesenseClient() {.dirty.} =
  var ts = newClient(address, Port(8108), rootkey)

test "can init":
  newTypesenseClient()
  assert waitFor(ts.health())

test "/keys POST":
  # Create a new key
  newTypesenseClient()
  let key = waitFor ts.keys.create("Some key")
  assert key.getActions == {tsAnyActions}

test "/keys GET":
  # Get all keys
  newTypesenseClient()
  let allkeys = waitFor ts.keys.retrieve 
  assert allkeys.len != 0

test "/keys/{id} GET":
  # Get a key by id
  newTypesenseClient()
  # let akey = waitFor ts.keys.retrieve(0)

test "/keys DELETE":
  # Delete a key by id
  newTypesenseClient()
  waitFor ts.keys.deleteAll()
  let allkeys = waitFor ts.keys.retrieve
  assert allkeys.len == 0

test "/collections POST":
  # Create a new collection
  newTypesenseClient()
  let col: Collection =
    waitFor ts.collections.create(
      name = "companies",
      fields = @[
        newField("company_name", tstype(string), false),
        newField("num_employees", tstype(int32), false),
        newField("country", tstype(string), false)
      ],
      defaultSortingField = "num_employees"
    )

test "/collections GET":
  # Get all collections
  newTypesenseClient()
  let collections: seq[Collection] = waitFor ts.collections.retrieve()
  assert collections.len != 0