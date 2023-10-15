import std/[unittest, parsecfg, strutils, asyncdispatch, json]
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

#
# Keys
#
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

#
# Collections
#
test "POST   /collections":
  # Create a new collection
  echo repeat("-", 30)
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
  let col = waitFor ts.collection("companies").retrieve()

test "PATCH  /collections/{name}":
  ## Update fields
  newTypesenseClient()
  waitFor ts.collection("companies").update(@[
    drop("country"),
    field("location", % seq[(float, float)], false)
  ])

test "DELETE /collections/{name}":
  ## Delete a collection by name
  newTypesenseClient()
  assert waitFor(ts.collection("companies").exists) == true
  waitFor ts.collection("companies").delete()
  assert waitFor(ts.collection("companies").exists) == false

test "DELETE /collections (all)":
  # Delete all collections
  newTypesenseClient()
  waitFor ts.collections.deleteAll()

#
# Documents
#
test "POST  /collections/{name}/documents":
  # Create a new document
  echo repeat("-", 30)
  newTypesenseClient()
  # first, create a collection
  let col: Collection =
    waitFor ts.collections.create(
      name = "companies",
      fields = @[
        field("id", % string, false), # id must be a string
        field("company_name", % string, false),
        field("num_employees", % int32, false),
        field("country", % string, false)
      ],
      defaultSortingField = "num_employees"
    )
  block:
    let doc: Document = %*{
      "id": "123",
      "company_name": "Stark Industries",
      "num_employees": 5215,
      "country": "USA"
    }
    waitFor ts.collection("companies").documents.create(doc)
  block:
    let doc: Document = %*{
      "id": "123",
      "company_name": "Stark Industries",
      "num_employees": 5215,
      "country": "Germany"
    }
    waitFor ts.collection("companies").documents.create(doc, docUpsert)

test "GET   /collections/{name}/documents/{id}":
  # Retrieve a Document from Collection
  newTypesenseClient()
  let doc: Document = waitFor ts.collection("companies").document("123").retrieve
  assert doc != nil
  echo doc

test "GET   /collections/{name}/documents/export":
  # Export Documents from Collection
  newTypesenseClient()
  waitFor ts.collection("companies").documents.exports()
  waitFor ts.collections.deleteAll()