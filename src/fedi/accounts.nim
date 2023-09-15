import client
import httpclient
import asyncdispatch
import json
import strformat
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

proc getTimeline*(client: FediClient or AsyncFediClient, instance: string, local = false, remote = false, limit = 40): Future[JsonNode] {.multisync.} =
  let req = await client.hc.get(fmt"{instance}/api/v1/timelines/public")
  await castRateLimit(res=req, client=client.hc)
  castError req
  return (await req.body).parseJson

proc getTimeline*(client: FediClient or AsyncFediClient, local = false, remote = false, limit = 40): Future[JsonNode] {.multisync.} =
  let url = client.makeUrl("/api/v1/timelines/public")
  let req = await client.hc.get(url)
  await castRateLimit(res=req, client=client.hc)
  castError req
  return (await req.body).parseJson

proc getStatuses*(client: FediClient or AsyncFediClient, accountId: string, limit: int = 20, onlyMedia: bool = false, excludeReplies: bool = false ): Future[JsonNode] {.multisync.} =
  let url = client.makeUrl(fmt"/api/v1/accounts/{accountId}/statuses")
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