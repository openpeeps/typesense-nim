# Nim client for Typesense, a fast, typo tolerant, 
# in-memory fuzzy search engine.
#
#   (c) 2023 George Lemon | MIT License
#   Made by Humans from OpenPeeps

import std/[sequtils, strutils]
import pkg/jsony

type
  TypesenseActions* = enum
    tsCollectionAll = "collections:*"
      ## Allow all kinds of collection related operations.
    tsCollectionCreate = "collections:create"
      ## Allows a collection to be created.
    tsCollectionDelete = "collections:delete"
      ## Allows a collection to be deleted.
    tsCollectionGet = "collections:get"
      ## Allows a collection schema to be retrieved.
    tsCollectionList = "collections:list"
      ## Allows retrieving all collection schema.

    # Documents
    tsDocumentAll = "documents:*"
      ## Allows all document operations.
    tsDocumentSearch = "documents:search"
      ## Allows only search requests.
    tsDocumentGet = "documents:get"
      ## Allows fetching a single document.
    tsDocumentCreate = "documents:create"
      ## Allows creating documents.
    tsDocumentUpsert = "documents:upsert"
      ## Allows upserting documents.
    tsDocumentUpdate = "documents:update"
      ## Allows updating documents.
    tsDocumentDelete = "documents:delete"
      ## Allows deletion of documents.
    tsDocumentImport = "documents:import"
      ## Allows import of documents in bulk.
    tsDocumentExport = "documents:export"
      ## Allows export of documents in bulk.

    # Aliases
    tsAliasAll = "aliases:*"
      ## Allows all alias operations.
    tsAliasList = "aliases:list"
      ## Allows all aliases to be fetched.
    tsAliasGet = "aliases:get"
      ## Allows a single alias to be retrieved
    tsAliasCreate = "aliases:create"
      ## Allows the creation of aliases.
    tsAliasDelete = "aliases:delete"
      ## Allows the deletion of aliases

    # Synonyms
    tsSynonymAll = "synonyms:*"
      ## Allows all synonym operations.
    tsSynonymList = "synonyms:list"
      ## Allows all synonyms to be fetched.
    tsSynonymGet = "synonyms:get"
      ## Allows a single synonym to be retrieved
    tsSynonymCreate = "synonyms:create"
      ## Allows the creation of synonyms.
    tsSynonymDelete = "synonyms:delete"
      ## Allows the deletion of synonyms.

    # Overrides
    tsOverridesAll = "overrides:*"
      ## Allows all override operations.
    tsOverridesList = "overrides:list"
      ## Allows all overrides to be fetched.
    tsOverridesGet = "overrides:get"
      ## Allows a single override to be retrieved
    tsOverridesCreate = "overrides:create"
      ## Allows the creation of overrides.
    tsOverridesDelete = "overrides:delete"
      ## Allows the deletion of overrides.

    # Keys
    tsKeysAll = "keys:*"
      ## Allows all API Key related operations.
    tsKeysList = "keys:list"
      ## Allows fetching of metadata for all keys
    tsKeysGet = "keys:get"
      ## Allows metadata for a signle key to be fetched
    tsKeysCreate = "keys:create"
      ## Allows the creation of API keys.
    tsKeysDelete = "keys:delete"
      ## Allows the deletion of API keys.

    # Misc
    tsMiscAll = "*"
      ## Allow all operations
    tsMiscMetric = "metrics.json:list"
      ## Allows access to the metrics endpoints
    tsMiscDebug = "debug:list"
      ## Allows access to the `/debug` endpoint

proc getActions*(actions: set[TypesenseActions]): seq[string] =
  actions.toSeq.map do:
    proc(x: TypesenseActions): string = $x
