# Nim client for Typesense, a fast, typo tolerant, 
# in-memory fuzzy search engine.
#
#   (c) 2023 George Lemon | MIT License
#   Made by Humans from OpenPeeps

import std/[httpclient, httpcore, net,
  asyncdispatch, times, strutils, sequtils, json]

import pkg/jsony
import ./actions

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
    tsEndpointStatus = "/health"
    tsEndpointCollections = "/collections"
    tsEndpointKeys = "/keys"

  JsonResponse = (HttpCode, JsonNode)
  TypesenseClientError* = object of CatchableError

proc getUrl*(client: TypesenseClient, ep: TypesenseEndpoint): string =
  result = "http://$1:$2/$3" % [client.config.url, $(client.config.port), $(ep)]

proc getUrl*(client: TypesenseClient, ep: TypesenseEndpoint, paths: openarray[string]): string =
  client.getUrl(ep) & "/" & paths.join("/")

proc parseJson*(res: AsyncResponse): Future[JsonNode] {.async.} =
  jsony.fromJson(await res.body(), JsonNode)

proc newClient*(address: string, port: Port, apiKey: string): TypesenseClient =
  ## Create a new `TypesenseClient`
  result = TypesenseClient(config: TypesenseConfig(url: address, port: port))
  var headers = newHttpheaders([
    ("x-typesense-api-key", apiKey),
    ("content-type", "application/json")
  ])
  result.httpClient = newAsyncHttpClient(headers = headers)
  result.httpClient.timeout = inMilliseconds(result.config.timeout)

proc native*[T](ts: T): TypesenseClient =
  result = TypesenseClient(ts)

proc get*(client: TypesenseClient, ep: TypesenseEndpoint, paths: openarray[string] = []): Future[AsyncResponse] =
  # Make a `GET` request to `ep` TypesenseEndpoint
  return client.httpClient.get(client.getUrl(ep, paths))

proc post*(client: TypesenseClient, ep: TypesenseEndpoint, data: JsonNode): Future[AsyncResponse] =
  # Make a `POST` request to `ep` TypesenseEndpoint
  return client.httpClient.post(client.getUrl(ep), body = $(data))

proc delete*(client: TypesenseClient, ep: TypesenseEndpoint, paths: openarray[string]): Future[AsyncResponse] =
  # Make a `DELETE` request to `ep` TypesenseEndpoint
  return client.httpClient.delete(client.getUrl(ep, paths))

template raiseClientException* {.dirty.} =
  block:
    var body = jsony.fromJson(body, JsonNode)
    let msg =
      if body.hasKey("message"):
        body["message"].getStr
      else: ""
    raise newException(TypesenseClientError,
      $(res.code) & ": " & msg)
