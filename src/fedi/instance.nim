import std/[asyncdispatch, json]

import client, utils


proc instance*(client: FediClient or AsyncFediClient): Future[JsonNode]
    {.multisync.} =
  return await client.requestJson("api/v2/instance")


proc getStats*(client: FediClient or AsyncFediClient): Future[JsonNode]
    {.multisync, deprecated: "Use instance() for the Mastodon v2 endpoint".} =
  return await client.requestJson("api/v1/instance")


proc getPeers*(client: FediClient or AsyncFediClient): Future[seq[string]]
    {.multisync.} =
  let data = await client.requestJson("api/v1/instance/peers")
  for item in data.items:
    result.add(item.getStr)


proc weeklyActivity*(client: FediClient or AsyncFediClient): Future[JsonNode]
    {.multisync.} =
  return await client.requestJson("api/v1/instance/activity")


proc getRules*(client: FediClient or AsyncFediClient): Future[JsonNode]
    {.multisync.} =
  return await client.requestJson("api/v1/instance/rules")


proc getActiveUserCount*(client: FediClient or AsyncFediClient): Future[int]
    {.multisync.} =
  let data = await client.instance()
  result = data{"usage"}{"users"}{"active_month"}.getInt(0)


proc getUserCount*(client: FediClient or AsyncFediClient): Future[int]
    {.multisync, deprecated: "Mastodon v1 instance statistics are deprecated; use getActiveUserCount()".} =
  let data = await client.getStats()
  result = data{"stats"}{"user_count"}.getInt(0)


proc publicTimelinePath*(local = false, remote = false,
                         onlyMedia = false, limit = 20,
                         maxId = "", minId = "", sinceId = ""): string =
  if local and remote:
    raise newException(ValueError, "local and remote cannot both be true")

  var params: seq[QueryParam]
  params.addQueryParam("local", local)
  params.addQueryParam("remote", remote)
  params.addQueryParam("only_media", onlyMedia)
  params.addQueryParam("limit", max(1, min(40, limit)))
  params.addQueryParam("max_id", maxId)
  params.addQueryParam("min_id", minId)
  params.addQueryParam("since_id", sinceId)
  result = "api/v1/timelines/public" & buildQuery(params)


proc getTimeline*(client: FediClient or AsyncFediClient,
                  local = false, remote = false,
                  onlyMedia = false, limit = 20,
                  maxId = "", minId = "", sinceId = ""): Future[JsonNode]
    {.multisync.} =
  return await client.requestJson(publicTimelinePath(
    local = local,
    remote = remote,
    onlyMedia = onlyMedia,
    limit = limit,
    maxId = maxId,
    minId = minId,
    sinceId = sinceId
  ))


proc getTimeline*(client: FediClient or AsyncFediClient,
                  instanceHost: string,
                  local = false, remote = false,
                  onlyMedia = false, limit = 20,
                  maxId = "", minId = "", sinceId = ""): Future[JsonNode]
    {.multisync.} =
  let url = normalizeHost(instanceHost) & "/" & publicTimelinePath(
    local = local,
    remote = remote,
    onlyMedia = onlyMedia,
    limit = limit,
    maxId = maxId,
    minId = minId,
    sinceId = sinceId
  )
  return await client.requestJsonUrl(url)
