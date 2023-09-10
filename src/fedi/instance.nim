import client
import httpclient
import asyncdispatch
import strformat
import json

proc instance*(client, FediClient or AsyncFediClient): Future[JsonNode] {.multisync.} =
  ## https://docs.joinmastodon.org/methods/instance/#v2
  let url = client.makeUrl("/api/v2/instance")
  let req = await client.hc.get(url)
  await castRateLimit(res=req, client=client.hc)
  castError req
  let data = (await req.body).parseJson
  return data


proc getStats*(client: FediClient or AsyncFediClient): Future[JsonNode] {.multisync, deprecated.} =
  let url = client.makeUrl("/api/v1/instance")
  let req = await client.hc.get(url)

  await castRateLimit(res=req, client=client.hc)
  castError req
  return (await req.body).parseJson




proc getPeers*(client: FediClient or AsyncFediClient): Future[seq[string]] {.multisync.} =
  ## https://docs.joinmastodon.org/methods/instance/#peers
  let url = client.makeUrl("/api/v1/instance/peers")
  let req = await client.hc.get(url)

  await castRateLimit(res=req, client=client.hc)
  castError req
  let data = (await req.body).fromJson(seq[string])
  return data


proc weeklyActivity*(client: FediClient or AsyncFediClient): Future[JsonNode] {.multisync.} =
  ## https://docs.joinmastodon.org/methods/instance/#activity
  let url = client.makeUrl("/api/v1/instance/activity")
  let req = await client.hc.get(url)
  await castRateLimit(res=req, client=client.hc)
  castError req
  let data = (await req.body).parseJson
  return data


proc getRules*(client: FediClient or AsyncFediClient): Future[JsonNode] {.multisync.} =
  ## https://docs.joinmastodon.org/methods/instance/#rules



proc getUserCount*(client: FediClient or AsyncFediClient): Future[int] {.multisync.} =
  let url = client.makeUrl("/api/v1/instance")
  let req = await client.hc.get(url)

  await castRateLimit(res=req, client=client.hc)
  castError req
  let data = (await req.body).parseJson
  result = data["stats"]["user_count"].getInt