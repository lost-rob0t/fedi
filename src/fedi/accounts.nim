import std/[asyncdispatch, json, strformat]

import client, utils


proc verifyAccountCreds*(client: FediClient or AsyncFediClient): Future[JsonNode]
    {.multisync.} =
  return await client.requestJson("api/v1/accounts/verify_credentials")


proc getAccountInfo*(client: FediClient or AsyncFediClient,
                     accountId: string): Future[JsonNode] {.multisync.} =
  return await client.requestJson(fmt"api/v1/accounts/{accountId}")


proc accountStatusesPath*(accountId: string, limit = 20,
                          onlyMedia = false, excludeReplies = false,
                          excludeReblogs = false, tagged = "",
                          maxId = "", minId = "", sinceId = ""): string =
  var params: seq[QueryParam]
  params.addQueryParam("limit", max(1, min(40, limit)))
  params.addQueryParam("only_media", onlyMedia)
  params.addQueryParam("exclude_replies", excludeReplies)
  params.addQueryParam("exclude_reblogs", excludeReblogs)
  params.addQueryParam("tagged", tagged)
  params.addQueryParam("max_id", maxId)
  params.addQueryParam("min_id", minId)
  params.addQueryParam("since_id", sinceId)
  result = fmt"api/v1/accounts/{accountId}/statuses" & buildQuery(params)


proc getStatuses*(client: FediClient or AsyncFediClient,
                  accountId: string, limit = 20,
                  onlyMedia = false, excludeReplies = false,
                  excludeReblogs = false, tagged = "",
                  maxId = "", minId = "", sinceId = ""): Future[JsonNode]
    {.multisync.} =
  return await client.requestJson(accountStatusesPath(
    accountId = accountId,
    limit = limit,
    onlyMedia = onlyMedia,
    excludeReplies = excludeReplies,
    excludeReblogs = excludeReblogs,
    tagged = tagged,
    maxId = maxId,
    minId = minId,
    sinceId = sinceId
  ))


proc getFollowers*(client: FediClient or AsyncFediClient,
                   accountId: string, limit = 40,
                   maxId = "", sinceId = ""): Future[JsonResponse]
    {.multisync.} =
  var params: seq[QueryParam]
  params.addQueryParam("limit", max(1, min(80, limit)))
  params.addQueryParam("max_id", maxId)
  params.addQueryParam("since_id", sinceId)
  let endpoint = fmt"api/v1/accounts/{accountId}/followers" & buildQuery(params)
  return await client.requestJsonWithHeaders(client.makeUrl(endpoint))


proc lookupAccount*(client: FediClient or AsyncFediClient,
                    acct: string): Future[JsonNode] {.multisync.} =
  var params: seq[QueryParam]
  params.addQueryParam("acct", acct)
  return await client.requestJson("api/v1/accounts/lookup" & buildQuery(params))
