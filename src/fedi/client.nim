import std/[asyncdispatch, httpclient, httpcore, json, os, strformat, strutils, times]

const
  DefaultUserAgent* = "fedi/1.0.0 (+https://github.com/lost-rob0t/fedi)"


type
  BaseFediClient = object of RootObj
    baseUrl*: string

  AsyncFediClient* = object of BaseFediClient
    hc*: AsyncHttpClient

  FediClient* = object of BaseFediClient
    hc*: HttpClient

  JsonResponse* = tuple[headers: HttpHeaders, data: JsonNode]

  FediError* = object of CatchableError
    responseCode*: HttpCode
    info*: JsonNode
    retryAfterMs*: int


func newFediError*(responseCode: HttpCode, info: JsonNode,
                   retryAfterMs = 0): ref FediError =
  result = newException(FediError, "Mastodon API request failed with HTTP " & $responseCode)
  result.responseCode = responseCode
  result.info = info
  result.retryAfterMs = retryAfterMs


proc normalizeHost*(host: string): string =
  result = host.strip()
  if result.len == 0:
    raise newException(ValueError, "Mastodon host cannot be empty")

  if not result.startsWith("https://") and not result.startsWith("http://"):
    result = "https://" & result

  while result.len > 0 and result[^1] == '/':
    result.setLen(result.len - 1)


proc makeUrl*(client: AsyncFediClient or FediClient, endpoint: string): string =
  var path = endpoint.strip()
  while path.len > 0 and path[0] == '/':
    path.delete(0, 0)
  result = client.baseUrl & "/" & path


proc requestHeaders(token: string): HttpHeaders =
  result = newHttpHeaders()
  result["Accept"] = "application/json"
  result["Content-Type"] = "application/json"
  if token.len > 0:
    result["Authorization"] = "Bearer " & token


proc newFediClient*(host: string, token = "", proxy = "",
                    userAgent = DefaultUserAgent): FediClient =
  var http: HttpClient
  if proxy.len > 0:
    http = newHttpClient(proxy = newProxy(proxy), userAgent = userAgent)
  else:
    http = newHttpClient(userAgent = userAgent)
  http.headers = requestHeaders(token)
  result = FediClient(hc: http, baseUrl: normalizeHost(host))


proc newAsyncFediClient*(host: string, token = "", proxy = "",
                         userAgent = DefaultUserAgent): AsyncFediClient =
  var http: AsyncHttpClient
  if proxy.len > 0:
    http = newAsyncHttpClient(proxy = newProxy(proxy), userAgent = userAgent)
  else:
    http = newAsyncHttpClient(userAgent = userAgent)
  http.headers = requestHeaders(token)
  result = AsyncFediClient(hc: http, baseUrl: normalizeHost(host))


proc close*(client: FediClient) =
  client.hc.close()


proc close*(client: AsyncFediClient) =
  client.hc.close()


proc headerValue(headers: HttpHeaders, name: string): string =
  headers.getOrDefault(name).toString.strip()


proc parseJsonBody(body: string): JsonNode =
  if body.len == 0:
    return newJNull()
  try:
    result = parseJson(body)
  except CatchableError:
    result = %*{"error": body}


proc parseResetTime(value: string): int64 =
  const formats = [
    "yyyy-MM-dd'T'HH:mm:ss'.'ffffff'Z'",
    "yyyy-MM-dd'T'HH:mm:ss'.'fff'Z'",
    "yyyy-MM-dd'T'HH:mm:ss'Z'",
    "yyyy-MM-dd'T'HH:mm:sszzz",
    "yyyy-MM-dd'T'HH:mm:ss'.'fff'zzz"
  ]

  for format in formats:
    try:
      return parseTime(value, format, utc()).toUnix
    except CatchableError:
      discard


proc rateLimitDelayMs*(headers: HttpHeaders): int =
  let remainingText = headerValue(headers, "x-ratelimit-remaining")
  if remainingText.len == 0:
    return 0

  try:
    if parseInt(remainingText) > 0:
      return 0
  except ValueError:
    return 0

  let retryAfter = headerValue(headers, "retry-after")
  if retryAfter.len > 0:
    try:
      return max(0, parseInt(retryAfter)) * 1000
    except ValueError:
      discard

  let resetText = headerValue(headers, "x-ratelimit-reset")
  if resetText.len > 0:
    let resetAt = parseResetTime(resetText)
    if resetAt > 0:
      let seconds = resetAt - getTime().toUnix
      if seconds > 0:
        return int(seconds * 1000)

  result = 1000


proc requestJsonWithHeaders*(client: AsyncFediClient,
                             url: string): Future[JsonResponse] {.async.} =
  let response = await client.hc.get(url)
  let body = await response.body
  let data = parseJsonBody(body)
  let delayMs = rateLimitDelayMs(response.headers)

  if not response.code.is2xx:
    raise newFediError(response.code, data, delayMs)

  if delayMs > 0:
    await sleepAsync(delayMs)

  result = (headers: response.headers, data: data)


proc requestJsonWithHeaders*(client: FediClient, url: string): JsonResponse =
  let response = client.hc.get(url)
  let data = parseJsonBody(response.body)
  let delayMs = rateLimitDelayMs(response.headers)

  if not response.code.is2xx:
    raise newFediError(response.code, data, delayMs)

  if delayMs > 0:
    sleep(delayMs)

  result = (headers: response.headers, data: data)


proc requestJson*(client: AsyncFediClient,
                  endpoint: string): Future[JsonNode] {.async.} =
  result = (await client.requestJsonWithHeaders(client.makeUrl(endpoint))).data


proc requestJson*(client: FediClient, endpoint: string): JsonNode =
  result = client.requestJsonWithHeaders(client.makeUrl(endpoint)).data


proc requestJsonUrl*(client: AsyncFediClient,
                     url: string): Future[JsonNode] {.async.} =
  result = (await client.requestJsonWithHeaders(url)).data


proc requestJsonUrl*(client: FediClient, url: string): JsonNode =
  result = client.requestJsonWithHeaders(url).data
