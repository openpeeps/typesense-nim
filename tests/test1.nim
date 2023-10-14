import std/[unittest, parsecfg, strutils, asyncdispatch]
import typesense

let
  dict = loadConfig("/etc/typesense/typesense-server.ini")
  rootkey = dict.getSectionValue("server", "api-key").strip()
  address = "0.0.0.0"
  # rootkey = "bV9ZXnOpBFc1CPivLCvZ74OuutTniiei44lyziQqrFgACsZy"
  # address = "10.242.195.202"

template newTypesenseClient() {.dirty.} =
  var ts = newClient(address, rootkey, Port(8108))

test "init":
  newTypesenseClient()
  assert waitFor(ts.health())

test "POST   /keys":
  # Create a new key
  newTypesenseClient()
  let key = waitFor ts.keys.create("Some key")
  assert key.getActions == {tsAnyActions}

test "GET    /keys":
  # Get all keys
  newTypesenseClient()
  let allkeys = waitFor ts.keys.retrieve 
  assert allkeys.len != 0

test "GET    /keys/{id}":
  # Get a key by id
  newTypesenseClient()
  # let akey = waitFor ts.keys.retrieve(0)

test "DELETE /keys":
  # Delete a key by id
  newTypesenseClient()
  waitFor ts.keys.deleteAll()
  let allkeys = waitFor ts.keys.retrieve
  assert allkeys.len == 0

test "POST   /collections":
  # Create a new collection
  newTypesenseClient()
  let col: Collection =
    waitFor ts.collections.create(
      name = "companies",
      fields = @[
        field("company_name", % string, false),
        field("num_employees", % int32, false),
        field("country", % string, false)
      ],
      defaultSortingField = "num_employees"
    )

test "GET    /collections":
  # Get all collections
  newTypesenseClient()
  let collections: seq[Collection] = waitFor ts.collections.retrieve()
  assert collections.len == 1

test "GET    /collections/{name}":
  ## Get a collection by name
  newTypesenseClient()
  let col = waitFor ts.collections.retrieve("companies")

test "PATCH  /collections/{name}":
  ## Update fields
  newTypesenseClient()
  waitFor ts.collections.update("companies", @[
    drop("country"),
    field("location", % seq[(float, float)], false)
  ])

test "DELETE /collections/{name}":
  ## Delete a collection by name
  newTypesenseClient()
  waitFor ts.collections.delete("companies")

test "DELETE /collections (all)":
  ## Delete all collections
  newTypesenseClient()
  waitFor ts.collections.deleteAll()