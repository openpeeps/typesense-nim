# Nim client for Typesense, a fast, typo tolerant, 
# in-memory fuzzy search engine.
#
#   (c) 2023 George Lemon | MIT License
#   Made by Humans from OpenPeeps

import ./actions, ./client
import pkg/jsony
import std/[options, asyncdispatch, httpclient, json]

type
  TypesenseKeysClient* = distinct TypesenseClient
  Key* = ref object
    id: int
    actions: seq[TypesenseActions]
      # List of allowed actions. See next table for
      # possible values.
    collections: seq[string]
      # List of collections that this key is scoped to.
      # Supports regex. Eg: coll.* will match all collections that have "coll" in their name.
    description: string
      # Internal description to identify what the key is for
    expires_at: int64
      # Unix timestamp (opens new window)until which the key is valid
    value_prefix: string
    value: string
      # By default Typesense will auto-generate a random key
      # for you, when this parameter is not specified.
      # If you need to use a particular string as the key,
      # you can mention it using this parameter when
      # creating the key.

  Keys* = object
    ## Typesense allows you to create API Keys with fine-grained access
    ## control. You can restrict access on a per-collection,
    ## per-action, per-record or even per-field level or a
    ## mixture of these.
    ## Check [Typesense API Resources - API Keys](https://typesense.org/docs/0.25.1/api/api-keys.html)
    keys: seq[Key]

proc keys*(ts: TypesenseClient): TypesenseKeysClient {.inline.} =
  ## Returns a HttpClient for managing `/keys` API endpoint
  result = TypesenseKeysClient ts

proc create*(ts: TypesenseKeysClient, desc: string,
    actions: set[TypesenseActions] = {tsDocumentSearch},
    collections: seq[string] = @["*"]): Future[Key] {.async.} =
  ## Create a new Key with given permissions
  let data = %*{
    "description": desc,
    "actions": actions.getActions(),
    "collections": collections
  }
  let res = await ts.native.post(tsEndpointKeys, data)
  let body = await res.body 
  case res.code
    of Http201:
      result = jsony.fromJson(body, Key)
    else: raiseClientException()

proc retrieve*(ts: TypesenseKeysClient): Future[Keys] {.async.} =
  ## Retrieve available `Keys`
  let res = await ts.native.get(tsEndpointKeys)
  let body = await res.body
  case res.code:
    of Http200:
      result = jsony.fromJson(body, Keys)
    else:
      raiseClientException()

proc retrieve*(ts: TypesenseKeysClient, id: int): Future[Key] {.async.} =
  ## Retrieve a `Key` by `id` from available `Keys`
  let res = await ts.native.get(tsEndpointKeys, [$id])
  let body = await res.body
  case res.code:
    of Http200:
      result = jsony.fromJson(body, Key)
    else:
      raiseClientException()

proc delete*(ts: TypesenseKeysClient, id: int): Future[Option[int]] {.async.} =
  ## Delete a specific `Key` by `id`
  let res = await ts.native.delete(tsEndpointKeys, [$id])
  let body = await res.body
  case res.code:
    of Http200:
      let resp = jsony.fromJson(body, JsonNode)
      result = some(resp["id"].getInt)
    else: discard

proc `$`*(k: Keys|Key): string =
  ## Convert one or more keys to stringified JSON
  jsony.toJson(k)