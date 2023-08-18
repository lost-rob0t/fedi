import jsony, json
import asyncdispatch
import httpclient
import strformat
import httpCore
import times
import strutils
import os
type
  BaseFediClient = object of RootObj
    baseUrl*: string
  AsyncFediClient* = object of BaseFediClient
    hc*: AsyncHttpClient
  FediClient* = object of BaseFediClient
    hc*: HttpClient

  FediError* = object of Defect
    responseCode*: HttpCode
    info*: JsonNode

# NOTE it should only be https, but i dont care. Use with your own risk.
func webfingerUser*(username: string, scheme: string): string =
  let data = username.split("@")
  result = fmt"{scheme}://{data[1]}/.well-known/webfinger?resource={username}"


func newFediError*(respCode: HttpCode, info: JsonNode): ref FediError =
  result = newException(FediError, "")
  result.responseCode = respCode
  result.info = info

template castError(res: Response) =
  if not res.code.is2xx:
    raise newFediError(res.code, res.body.parseJson)

template castError(res: AsyncResponse) =
  if not res.code.is2xx:
    raise newFediError(res.code, (await res.body).parseJson)

proc parseSleep*(header: HttpHeaders): int =
  ## Return the amount of seconds until ratelimit resets
  let resetTimeStr = header.getOrDefault("x-ratelimit-reset").toString
  let serverTimeStr = header.getOrDefault("date").toString
  let serverTime = parseTime(serverTimeStr, "ddd, dd MMM yyyy hh:mm:ss 'GMT'", utc()).toUnix
  let sleepTime = parseTime(resetTimeStr, "yyyy-MM-dd'T'HH:mm:ss'.'ffffff'Z'", utc()).toUnix
  result = int(sleepTime - serverTime)

proc checkRateLimit*(header: HttpHeaders): bool =
  ## Check if the ratelimit amount is 10 or lower, returns true if 10 or lower, and you should now sleep until reset time
  let left = header.getOrDefault("x-ratelimit-remaining").toString.parseInt
  when defined(debug):
    echo $left
  if left <= 10 or left == 0:
    when defined(debug):
      echo "Ratelimit left: ", $left
    result = true
  else:
    result = false

proc castRateLimit*(res: AsyncResponse, client: AsyncHttpClient) {.async.} =
  let sleepBool = res.headers.checkRateLimit()
  if sleepBool:
    client.close()
    let sleep = res.headers.parseSleep()
    when defined(debug):
      echo "Sleeping until ratelimit resets in: ", $sleep, ", secs"
    await sleepAsync(sleep * 1000)

proc castRateLimit*(res: Response, client: HttpClient) =
  let sleepBool = res.headers.checkRateLimit()
  if sleepBool:
    let sleep = res.headers.parseSleep()
    when defined(debug):
      echo "Sleeping until ratelimit resets in: ", $sleep, ", secs"
    sleep(sleep * 1000)



proc newFediClient*(host: string, token = "", proxy = "", userAgent = "GoyimFrei"): FediClient =
  var client: HttpClient
  if proxy != "":
    client = newHttpClient(proxy=newProxy(proxy), userAgent=userAgent)
  else:
    client = newHttpClient(userAgent=userAgent)

  client.headers = newHttpHeaders({ "Content-Type": "application/json" })
  if token.len > 0:
    client.headers = newHttpHeaders({ "Authorization": fmt"Bearer {token}" })
  FediClient(hc: client, baseUrl: host)

proc newAsyncFediClient*(host: string, token = "", proxy = "", userAgent = "GoyimFrei"): AsyncFediClient =
  var client: AsyncHttpClient
  if proxy != "":
    echo proxy
    client = newAsyncHttpClient(proxy=newProxy(proxy), userAgent=userAgent)
  else:
    client = newAsyncHttpClient(userAgent=userAgent)

  client.headers = newHttpHeaders({ "Content-Type": "application/json" })
  if token.len > 0:
    client.headers = newHttpHeaders({ "Authorization": fmt"Bearer {token}" })
  AsyncFediClient(hc: client, baseUrl: host)
proc makeUrl(self: AsyncFediClient or FediClient, endpoint: string): string =
  result = fmt"{self.baseUrl}/{endpoint}"

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

proc getStatuses*(client: FediClient or AsyncFediClient, accountId: string): Future[JsonNode] {.multisync.} =
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


proc getStats*(client: FediClient or AsyncFediClient): Future[JsonNode] {.multisync.} =
  let url = client.makeUrl("/api/v1/instance")
  let req = await client.hc.get(url)

  await castRateLimit(res=req, client=client.hc)
  castError req
  return (await req.body).parseJson


proc getUserCount*(client: FediClient or AsyncFediClient): Future[int] {.multisync.} =
  let url = client.makeUrl("/api/v1/instance")
  let req = await client.hc.get(url)

  await castRateLimit(res=req, client=client.hc)
  castError req
  let data = (await req.body).parseJson
  result = data["stats"]["user_count"].getInt

proc getPeers*(client: FediClient or AsyncFediClient): Future[seq[string]] {.multisync.} =
  let url = client.makeUrl("/api/v1/instance/peers")
  let req = await client.hc.get(url)

  await castRateLimit(res=req, client=client.hc)
  castError req
  let data = (await req.body).fromJson(seq[string])
  return data

proc getPeers*(client: FediClient or AsyncFediClient, instance: string): Future[seq[string]] {.multisync.} =
  let req = await client.hc.get(fmt"https://{instance}/api/v1/instance/peers")

  await castRateLimit(res=req, client=client.hc)
  castError req
  let data = (await req.body).fromJson(seq[string])
  return data


proc getStatus*(client: FediClient or AsyncFediClient, status: string): Future[JsonNode] {.multisync.} =
  let url = client.makeUrl(fmt"/api/v1/statuses/{status}")
  let req = await client.hc.get(url)

  await castRateLimit(res=req, client=client.hc)
  castError req
  let data = (await req.body).parseJson
  return data


proc getContext*(client: FediClient or AsyncFediClient, status: string): Future[JsonNode] {.multisync.} =
  let url = client.makeUrl(fmt"/api/v1/statuses/{status}/context")
  let req = await client.hc.get(url)

  await castRateLimit(res=req, client=client.hc)
  castError req
  let data = (await req.body).parseJson
  return data
