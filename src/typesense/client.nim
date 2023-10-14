# Nim client for Typesense, a fast, typo tolerant, 
# in-memory fuzzy search engine.
#
#   (c) 2023 George Lemon | MIT License
#   Made by Humans from OpenPeeps

import std/[httpclient, httpcore, net,
  asyncdispatch, times, strutils, sequtils, json]

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

  TypesenseClient* = object
    config: TypesenseConfig
    httpClient*: AsyncHttpClient
    httpHeaders: HttpHeaders

  TypesenseEndpoint* = enum
    tsEndpointStatus = "health"
    tsEndpointCollections = "collections"
    tsEndpointKeys = "keys"
    tsEndpointAliases = "aliases"

  JsonResponse = (HttpCode, JsonNode)
  TypesenseClientError* = object of CatchableError

proc getUrl*(ts: TypesenseClient, ep: TypesenseEndpoint): string =
  result = "http://$1:$2/$3" % [ts.config.url, $(ts.config.port), $(ep)]

proc getUrl*(ts: TypesenseClient, ep: TypesenseEndpoint, paths: openarray[string]): string =
  ts.getUrl(ep) & "/" & paths.join("/")

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

proc get*(ts: TypesenseClient, ep: TypesenseEndpoint, paths: openarray[string] = []): Future[AsyncResponse] =
  # Make a `GET` request to `ep` TypesenseEndpoint
  return ts.httpClient.get(ts.getUrl(ep, paths))

proc post*(ts: TypesenseClient, ep: TypesenseEndpoint, data: JsonNode): Future[AsyncResponse] =
  # Make a `POST` request to `ep` TypesenseEndpoint
  return ts.httpClient.post(ts.getUrl(ep), body = $(data))

proc post*(ts: TypesenseClient, ep: TypesenseEndpoint, data: string): Future[AsyncResponse] =
  # Make a `POST` request to `ep` TypesenseEndpoint
  return ts.httpClient.post(ts.getUrl(ep), body = data)

proc delete*(ts: TypesenseClient, ep: TypesenseEndpoint, paths: openarray[string]): Future[AsyncResponse] =
  # Make a `DELETE` request to `ep` TypesenseEndpoint
  return ts.httpClient.delete(ts.getUrl(ep, paths))

proc patch*(ts: TypesenseClient, ep: TypesenseEndpoint,
    paths: openarray[string], data: string): Future[AsyncResponse] =
  ## Make a `PATCH` request to `ep` TypesenseEndpoint
  return ts.httpClient.patch(ts.getUrl(ep, paths), body = data)

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
  case res.code:
    of Http200:
      status = fromJson(body, status.type)
      return status.ok
    else: discard

proc close*(ts: TypesenseClient) {.inline.} =
  ts.httpClient.close()