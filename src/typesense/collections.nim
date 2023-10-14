# Nim client for Typesense, a fast, typo tolerant, 
# in-memory fuzzy search engine.
#
#   (c) 2023 George Lemon | MIT License
#   Made by Humans from OpenPeeps

import ./client
import pkg/jsony
import std/[asyncdispatch, httpclient, json, macros, strutils]

type
  CollectionClient* = distinct TypesenseClient
  CollectionsClient* = distinct TypesenseClient

  CollectionFieldType* = distinct string 

  CollectionField* = object
    name: string
    `type`: CollectionFieldType
    facet: bool
    drop: bool

  Collection* = object
    ## In Typesense, every record you index is called a Document
    ## and a group of documents with similar fields is called a Collection.
    ## 
    ## A Collection is roughly equivalent to a table in a relational database.
    ## Check [Typesense API Resources - Collections](https://typesense.org/docs/0.25.1/api/collections.html)
    name: string
      # Name of the collection you wish to create.
    num_documents: int
    fields: seq[CollectionField]
      # A list of fields that you wish to index for querying,
      # filtering and faceting. For each field, you have to
      # specify at least it's `name` and `type`.
      # Example:
      # ```{"name": "title", "type": "string", "facet": false, "index": true}```
    token_separators: seq[char]
      # List of symbols or special characters to be used for
      # splitting the text into individual words in addition
      # to space and new-line characters.
    symbols_to_index: seq[char]
      # List of symbols or special characters to be indexed.
    default_sorting_field: string

macro `%`*(x: typedesc): untyped =
  ## Convert `CollectionFieldType` to Typesense field type.
  ## Where `x` can be:
  ## ```
  ## string, seq[string], int32, seq[int32],
  ## int64, seq[int64], float, seq[float], bool,
  ## seq[bool], (float, float), seq[(float, float)], object, auto
  ## ```
  ## Note that `(float, float)` is used to represent `geopoint`
  ## field type (latitude and longitude specified as [lat, lng]),
  ## and `seq[(float, float)] converts to `geopoint[]`.
  var str = x.repr
  # this is kinda stupid
  if str.startsWith("seq[("):
    str = "geopoint"
  elif str.startsWith("("):
    str = "geopoint[]"
  elif str.startsWith("seq"):
    str = str[4..^2] & "[]"
  result = newCall(
    ident("CollectionFieldType"),
    newLit(str)
  )

proc dumpHook*(s: var string, field: CollectionField) =
  case field.drop
  of true:
    add s, "{"
    add s, "\"name\":\"" & field.name & "\","
    add s, "\"drop\":" & $(field.drop)
    add s, "}"
  else:
    add s, "{"
    add s, "\"name\":\"" & field.name & "\","
    add s, "\"type\":\"" & string(field.`type`) & "\","
    add s, "\"facet\":" & $(field.facet)
    add s, "}"

proc field*(name: string, `type`: CollectionFieldType, facet: bool): CollectionField =
  ## Create a new `CollectionField`
  result.name = name
  result.`type` = `type`
  result.facet = facet

proc drop*(name: string): CollectionField =
  ## Drop a `CollectionField` by name
  result.name = name
  result.drop = true

proc collection*(ts: TypesenseClient, name: string = ""): CollectionClient {.inline.} =
  ## Returns a `CollectionClient` for managing
  ## a single collection via `/collections/{name}` API endpoint
  result = CollectionClient(ts)
  result.setpath(name)

proc collections*(ts: TypesenseClient): CollectionsClient =
  ## Returns a `CollectionsClient` for managing
  ## `/collections` API endpoint  
  result = CollectionsClient(ts)

proc create*(ts: CollectionsClient, name: string,
    fields: seq[CollectionField], defaultSortingField: string): Future[Collection] {.async.} =
  ## Create a new `Collection` from `schema`
  let data = "{\"name\":\"" & name & "\",\"fields\":" & jsony.toJson(fields) & ",\"default_sorting_field\":\"" & defaultSortingField & "\"}"
  let res = await ts.native.post(tsEndpointCollections, data)
  let body = await res.body
  case res.code
  of Http201:
    result = jsony.fromJson(body, Collection)
  else:
    raiseClientException()

proc update*(ts: CollectionClient, fields: seq[CollectionField]): Future[void] {.async.} =
  ## Update a Collection by `collectionName`
  let data = "{\"fields\": " & jsony.toJson(fields) & "}"
  let res = await ts.native.patch(tsEndpointCollection, data)
  let body = await res.body
  case res.code:
  of Http200: discard
  else: raiseClientException()

proc retrieve*(ts: CollectionsClient): Future[seq[Collection]] {.async.} =
  ## Returns a summary of all your collections.
  ## The collections are returned sorted by creation date,
  ## with the most recent collections appearing first
  let res = await ts.native.get(tsEndpointCollections)
  let body = await res.body
  case res.code
  of Http200:
    result = jsony.fromJson(body, seq[Collection])
  else:
    raiseClientException()

proc retrieve*(ts: CollectionClient): Future[Collection] {.async.} =
  ## Retrieve a `Collection` by `collectionName`
  let res = await ts.native.get(tsEndpointCollection)
  let body = await res.body
  case res.code
  of Http200:
    result = jsony.fromJson(body, Collection)
  else:
    raiseClientException()

proc exists*(ts: CollectionClient): Future[bool] {.async.} =
  ## Determine if a Collection exists by name
  let res = await ts.native.get(tsEndpointCollection)
  case res.code
  of Http200:
    return true
  of Http404:
    return false
  else:
    let body = await res.body
    raiseClientException()

proc delete*(ts: CollectionClient): Future[void] {.async.} =
  ## Permanently drops a collection. This action cannot be undone.
  ## For large collections, this might have an impact on read latencies.
  let res = await ts.native.delete(tsEndpointCollection)

proc deleteAll*(ts: CollectionsClient): Future[void] {.async.} =
  ## Performs a `GET` request to fetch available
  ## collections. Then, makes multiple `DELETE` requests
  ## for deleting each Collection, one by one.
  let all: seq[Collection] = await ts.retrieve()
  for x in all:
    var ts = TypesenseClient(ts)
    await ts.collection(x.name).delete

proc `$`*(k: seq[Collection]): string = jsony.toJson(k)
proc `$`*(k: Collection): string = jsony.toJson(k)