import httpclient
import asyncdispatch
import json
import times
from strutils import parseInt
from os import sleep
import strformat
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

func newFediError*(respCode: HttpCode, info: JsonNode): ref FediError =
  result = newException(FediError, "")
  result.responseCode = respCode
  result.info = info

template castError*(res: Response) =
  if not res.code.is2xx:
    raise newFediError(res.code, res.body.parseJson)

template castError*(res: AsyncResponse) =
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

proc newAsyncFediClient*(host: string, token = "", proxy = "", userAgent = "fediClient"): AsyncFediClient =
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
proc makeUrl*(self: AsyncFediClient or FediClient, endpoint: string): string =
  result = fmt"{self.baseUrl}/{endpoint}"
