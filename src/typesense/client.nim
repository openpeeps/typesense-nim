# Nim client for Typesense, a fast, typo tolerant, 
# in-memory fuzzy search engine.
#
#   (c) 2023 George Lemon | MIT License
#   Made by Humans from OpenPeeps

import std/[httpclient, httpcore, net, asyncdispatch,
    times, strutils, sequtils, json, uri]

import pkg/jsony

import ./actions
export actions

export net.Port
export httpclient, asyncdispatch

type
  TypesenseConfig* = object
    url: string
    port: Port
    key: string
    timeout: Duration = initDuration(seconds = 4)
    circuitBreakerName: string = "typesenseClient"
    circuitBreakerMaxRequests: uint32
    circuitBreakerInterval: TimeInterval
    circuitBreakerTimeout: Duration
    # circuitBreakerReadyToTrip
    # circuitBreakerOnStateChange

  TypesenseClient* = ref object
    config: TypesenseConfig
    httpClient*: AsyncHttpClient
    httpHeaders: HttpHeaders
    subpaths: seq[string]

  TypesenseEndpoint* = enum
    tsEndpointStatus = "health"
    tsEndpointKeys = "keys"
    tsEndpointKey = "keys/$1"
    tsEndpointAliases = "aliases"
    tsEndpointAlias = "aliases/$1"
    tsEndpointCollections = "collections"
    tsEndpointCollection = "collections/$1"
    tsEndpointDocuments = "collections/$1/documents"
    tsEndpointDocument = "collections/$1/documents/$2"
    tsEndpointDocumentsExport = "collections/$1/documents/export"

  JsonResponse = (HttpCode, JsonNode)
  TypesenseClientError* = object of CatchableError

proc getUrl*(ts: TypesenseClient, ep: TypesenseEndpoint): string =
  ## Compose Typesense URI from `ep` endpoint
  result = "http://$1:$2/$3" % [ts.config.url, $(ts.config.port), $(ep)]
  if ts.subpaths.len > 0:
    return result % ts.subpaths

proc parseJson*(res: AsyncResponse): Future[JsonNode] {.async.} =
  ## Parse response body to JsonNode
  jsony.fromJson(await res.body(), JsonNode)

proc newClient*(address: string, apiKey: string, port: Port = Port(8108)): TypesenseClient =
  ## Create a new `TypesenseClient`
  result = TypesenseClient(config: TypesenseConfig(url: address, port: port))
  var headers = newHttpheaders([
    ("x-typesense-api-key", apiKey),
    ("content-type", "application/json")
  ])
  result.httpClient = newAsyncHttpClient(headers = headers)
  result.httpClient.timeout = inMilliseconds(result.config.timeout)
  result.httpClient.close()

proc native*[T](ts: T): TypesenseClient =
  result = TypesenseClient(ts)

proc setpath*[T](ts: T, path: string) =
  var x = TypesenseClient(ts)
  x.subpaths.add(path)

proc get*(ts: TypesenseClient, ep: TypesenseEndpoint): Future[AsyncResponse] =
  # Make a `GET` request to `ep` TypesenseEndpoint
  result = ts.httpClient.get(ts.getUrl(ep))
  setLen(ts.subpaths, 0)

proc get*(ts: TypesenseClient, ep: TypesenseEndpoint,
    queries: seq[(string, string)]): Future[AsyncResponse] =
  # Make a `GET` request to `ep` TypesenseEndpoint
  result = ts.httpClient.get(ts.getUrl(ep) & "?" & queries.encodeQuery())
  setLen(ts.subpaths, 0)

proc post*(ts: TypesenseClient, ep: TypesenseEndpoint, data: JsonNode): Future[AsyncResponse] =
  # Make a `POST` request to `ep` TypesenseEndpoint
  result = ts.httpClient.post(ts.getUrl(ep), body = $(data))
  setLen(ts.subpaths, 0)

proc post*(ts: TypesenseClient, ep: TypesenseEndpoint,
    data: JsonNode, queries: seq[(string, string)]): Future[AsyncResponse] =
  # Make a `POST` request to `ep` TypesenseEndpoint
  result = ts.httpClient.post(ts.getUrl(ep) & "?" & queries.encodeQuery(), body = $(data))
  setLen(ts.subpaths, 0)

proc post*(ts: TypesenseClient, ep: TypesenseEndpoint, data: string): Future[AsyncResponse] =
  # Make a `POST` request to `ep` TypesenseEndpoint
  result = ts.httpClient.post(ts.getUrl(ep), body = data)
  setLen(ts.subpaths, 0)

proc delete*(ts: TypesenseClient, ep: TypesenseEndpoint): Future[AsyncResponse] =
  # Make a `DELETE` request to `ep` TypesenseEndpoint
  result = ts.httpClient.delete(ts.getUrl(ep))
  setLen(ts.subpaths, 0)

proc patch*(ts: TypesenseClient, ep: TypesenseEndpoint, data: string): Future[AsyncResponse] =
  ## Make a `PATCH` request to `ep` TypesenseEndpoint
  result = ts.httpClient.patch(ts.getUrl(ep), body = data)
  setLen(ts.subpaths, 0)

template raiseClientException* {.dirty.} =
  block:
    var body = jsony.fromJson(body, JsonNode)
    let msg =
      if body.hasKey("message"):
        body["message"].getStr
      else: ""
    raise newException(TypesenseClientError,
      $(res.code) & ": " & msg)

proc health*(ts: TypesenseClient): Future[bool] {.async.} =
  let
    res = await ts.get(tsEndpointStatus)
    body = await res.body
  var status: tuple[ok: bool]
  case res.code
  of Http200:
    status = fromJson(body, status.type)
    return status.ok
  else: discard

proc close*(ts: TypesenseClient) {.inline.} =
  ts.httpClient.close()