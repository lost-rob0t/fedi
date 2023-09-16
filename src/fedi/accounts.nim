import client
import httpclient
import asyncdispatch
import json
import strformat
import private
import uri


proc verifyAccountCreds*(client: FediClient or AsyncFediClient): Future[JsonNode] {.multisync.} =
  let url = client.makeUrl("/api/v1/accounts/verify_credentials")
  let req = await client.hc.get(url)
  defer: client.hc.close()
  await castRateLimit(res=req, client=client.hc)
  castError req
  return (await req.body).parseJson



proc getAccountInfo*(client: FediClient or AsyncFediClient, accountId: string): Future[JsonNode] {.multisync.} =
  let url = client.makeUrl(fmt"/api/v1/accounts/{accountId}")
  let req = await client.hc.get(url)
  defer: client.hc.close()
  await castRateLimit(res=req, client=client.hc)
  castError req

  return (await req.body).parseJson


proc getStatuses*(client: FediClient or AsyncFediClient, accountId: string, limit: int = 20, onlyMedia, excludeReplies, excludeReblogs: bool = false, tagged: string = "", maxId, minId, sinceId: int = 0): Future[JsonNode] {.multisync, captureDefaults.} =
  let url = client.makeUrl(fmt"/api/v1/accounts/{accountId}/statuses?" & encodeQuery createNadd(
    newseq[DoubleStrTuple](),
    [
      limit,
      onlyMedia,
      excludeReplies,
      excludeReblogs,
      tagged,
      minId,
      maxId,
      sinceId
    ], defaults
  ))
  let req = await client.hc.get(url)
  await castRateLimit(res=req, client=client.hc)
  castError req
  return (await req.body).parseJson


proc getFollowers*(client: FediClient or AsyncFediClient,  accountId: string): Future[(HttpHeaders, JsonNode)] {.multisync.} =
  ## Returnes a named tuple
  ## if there is pagination check the next field
  ## json data is in the data field
  let url = client.makeUrl(fmt"/api/v1/accounts/{accountId}/followers")
  let req = await client.hc.get(url)
  defer: client.hc.close()
  await castRateLimit(res=req, client=client.hc)
  castError req
  return (next: req.headers, data: (await req.body).parseJson)


proc lookupAccount*(client: FediClient or AsyncFediClient, acct: string): Future[JsonNode] {.multisync.} =
  ## https://docs.joinmastodon.org/methods/accounts/#lookup
  let url = client.makeUrl(fmt"/api/v1/accounts/lookup?acct={acct}")
  let req = await client.hc.get(url)
  await castRateLimit(res=req, client=client.hc)
  castError req
  let data = (await req.body).parseJson
  return data


