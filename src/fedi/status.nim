import client
import httpclient
import asyncdispatch
import json
import strformat

proc getStatus*(client: FediClient or AsyncFediClient, status: string): Future[JsonNode] {.multisync.} =
  let url = client.makeUrl(fmt"/api/v1/statuses/{$status}")
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
