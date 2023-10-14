import ./client, ./collections
import pkg/jsony
import std/[asyncdispatch, httpclient, json, macros, strutils]

type
  DocumentsClient* = distinct TypesenseClient
  DocumentClient* = distinct TypesenseClient

  DocumentActionMode* = enum
    ## Besides batch-creating documents, you can also
    ## use the action query parameter to update documents
    ## using their id field.
    docCreate = "create"
      ## Creates a new document. Fails if a document with
      ## the same id already exists
    docUpsert = "upsert"
      ## Creates a new document or updates an existing document if
      ## a document with the same id already exists. Requires the
      ## whole document to be sent. For partial updates,
      ## use the update action below.
    docUpdate
      ## Updates an existing document. Fails if a document
      ## with the given id does not exist. You can send
      ## a partial document containing only the fields that
      ## are to be updated.
    docEmplace = "emplace"
      ## Creates a new document or updates an existing document
      ## if a document with the same id already exists.
      ## You can send either the whole document or a
      ## partial document for update.
  
  JSONL = distinct string
  Document* = JsonNode

proc json2jsonl(): JSONL =
  ## Convert JSON data to JSON Lines
  discard

proc documents*(ts: CollectionClient): DocumentsClient =
  ## Retirms a `DocumentsClient` for managing
  ## `/collections/documents` API endpoint
  result = DocumentsClient(ts)

proc document*(ts: CollectionClient, name: string): DocumentClient =
  ## Retrieve a specific Document by ID
  ts.setpath(name)
  result = DocumentClient(ts)

proc imports*(doc: JSONL, action: DocumentActionMode) =
  ## Import a new document via `POST` request.
  ## Be sure to increase `connectionTimeout` to at least 5 minutes
  ## or more for imports, when instantiating the `TypesenseClient`.

proc exports*(ts: DocumentsClient): Future[void] {.async.} =
  ## While exporting, you can use the following
  ## parameters to control the result of the export:
  ## 
  ## `filter_by`  Restrict the exports to documents that satisfies the filter by query.
  ## `include_fields` List of fields that should be present in the exported documents.
  ## `exclude_fields` List of fields that should not be present in the exported documents.
  let res = await ts.native.get(tsEndpointDocumentsExport)
  let body = await res.body
  echo res.code

proc create*(ts: DocumentsClient, doc: Document,
    actionMode: DocumentActionMode = docCreate): Future[void] {.async.} = 
  ## Create a new Document
  let res = await ts.native.post(tsEndpointDocuments, doc, @[("action", $actionMode)])
  case res.code
  of Http201:
    discard
  else:
    let body = await res.body
    raiseClientException()

proc retrieve*(ts: DocumentClient): Future[Document] {.async.} =
  ## Retrieves available Documents
  let res = await ts.native.get(tsEndpointDocument)
  let body = await res.body
  case res.code
  of Http200:
    return Document(jsony.fromJson(body, JsonNode))
  else:
    raiseClientException()