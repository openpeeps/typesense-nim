import std/[unittest, envvars, strutils]
import typesense

let TSKey = getEnv("TYPESENSE_KEY").strip()

test "can init":
  var ts = newClient(
    address = "0.0.0.0",
    port = Port(8108),
    apiKey = TSKey
  )