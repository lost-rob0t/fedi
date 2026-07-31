import std/[asyncdispatch, json, strformat]

import client, utils


proc getStatus*(client: FediClient or AsyncFediClient,
                statusId: string): Future[JsonNode] {.multisync.} =
  return await client.requestJson(fmt"api/v1/statuses/{statusId}")


proc getStatuses*(client: FediClient or AsyncFediClient,
                  statusIds: openArray[string]): Future[JsonNode] {.multisync.} =
  var params: seq[QueryParam]
  for statusId in statusIds:
    params.addQueryParam("id[]", statusId)
  return await client.requestJson("api/v1/statuses" & buildQuery(params))


proc getContext*(client: FediClient or AsyncFediClient,
                 statusId: string): Future[JsonNode] {.multisync.} =
  return await client.requestJson(fmt"api/v1/statuses/{statusId}/context")
