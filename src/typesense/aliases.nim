# Nim client for Typesense, a fast, typo tolerant, 
# in-memory fuzzy search engine.
#
#   (c) 2023 George Lemon | MIT License
#   Made by Humans from OpenPeeps

import std/[asyncdispatch, json]
import pkg/jsony

import ./client

type
  AliasesClient* = distinct TypesenseClient

  Alias* = object
    name: string
    collection_name: string

  Aliases* = object
    aliases: seq[Alias]

proc aliases*(ts: TypesenseClient): AliasesClient {.inline.} =
  ## Returns a `AliasesClient` for managing `/aliases` API endpoint
  result = AliasesClient ts

proc retrieve*(ts: AliasesClient): Future[Aliases] {.async.} =
  ## List all aliases and the corresponding collections that they map to.
  let res = await ts.native.get(tsEndpointAliases)
  let body = await res.body
  case res.code:
    of Http200:
      result = jsony.fromJson(body, Aliases)
    else: raiseClientException()

proc retrieve*(ts: AliasesClient, name: string): Future[Alias] {.async.} =
  ## Retrieve an Alias
  let res = await ts.native.get(tsEndpointAliases, [name])
  let body = await res.body
  case res.code:
    of Http200:
      result = jsony.fromJson(body, Alias)
    else: raiseClientException()
