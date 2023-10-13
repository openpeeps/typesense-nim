# Nim client for Typesense, a fast, typo tolerant, 
# in-memory fuzzy search engine.
#
#   (c) 2023 George Lemon | MIT License
#   Made by Humans from OpenPeeps

import ./client
import pkg/jsony
import std/[options, asyncdispatch, httpclient, json, macros]

type
  CollectionClient* = distinct TypesenseClient
  CollectionFieldType* = distinct string 
  CollectionField* = tuple[name: string, `type`: CollectionFieldType, facet: bool]
  Collection* = object
    ## In Typesense, every record you index is called a Document
    ## and a group of documents with similar fields is called a Collection.
    ## 
    ## A Collection is roughly equivalent to a table in a relational database.
    ## Check [Typesense API Resources - Collections](https://typesense.org/docs/0.25.1/api/collections.html)
    name*: string
      # Name of the collection you wish to create.
    num_documents: int
    fields*: seq[CollectionField]
      # A list of fields that you wish to index for querying,
      # filtering and faceting. For each field, you have to
      # specify at least it's `name` and `type`.
      # Example:
      # ```{"name": "title", "type": "string", "facet": false, "index": true}```
    token_separators*: seq[char]
      # List of symbols or special characters to be used for
      # splitting the text into individual words in addition
      # to space and new-line characters.
    symbols_to_index*: seq[char]
      # List of symbols or special characters to be indexed.
    default_sorting_field*: string

const tsFieldtypes = ["string", "seq[string]", "int32", "seq[int32]",
  "int64", "seq[int64]", "float", "seq[float]", "bool", "seq[bool]",
  "seq[tuple[lat, lng: float]]", "object", "auto"]

macro tstype*(x: typedesc): untyped =
  let str = x.repr
  if str in tsFieldtypes:
    result = newCall(
      ident("CollectionFieldType"),
      newLit(str)
    )
  else:
    raise newException(TypesenseClientError, "Unknown Field Type. Can be one of " & $(tsFieldtypes))

proc collections*(ts: TypesenseClient): CollectionClient {.inline.} =
  ## Returns a `HttpClient` for managing `/collections` API endpoint
  result = CollectionClient ts

proc retrieve*(ts: CollectionClient): Future[seq[Collection]] {.async.} =
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