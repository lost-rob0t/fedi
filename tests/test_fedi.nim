import std/[httpcore, strutils, unittest]

import fedi


suite "fedi URL handling":
  test "normalizes hosts and joins paths":
    let client = FediClient(baseUrl: normalizeHost("mastodon.example/"))
    check client.baseUrl == "https://mastodon.example"
    check client.makeUrl("/api/v2/instance") ==
      "https://mastodon.example/api/v2/instance"

  test "builds encoded WebFinger URLs":
    let url = webfingerUser("@alice@example.social")
    check url.startsWith("https://example.social/.well-known/webfinger?")
    check "resource=acct%3Aalice%40example.social" in url

  test "rejects malformed account names":
    expect ValueError:
      discard splitAccount("alice")


suite "fedi Mastodon paths":
  test "public timeline uses string cursors":
    let path = publicTimelinePath(
      local = true,
      onlyMedia = true,
      limit = 100,
      maxId = "109999999999999999",
      sinceId = "108888888888888888"
    )
    check path.startsWith("api/v1/timelines/public?")
    check "local=true" in path
    check "only_media=true" in path
    check "limit=40" in path
    check "max_id=109999999999999999" in path
    check "since_id=108888888888888888" in path

  test "account status path uses current parameter names":
    let path = accountStatusesPath(
      accountId = "123",
      excludeReplies = true,
      excludeReblogs = true,
      minId = "456"
    )
    check "exclude_replies=true" in path
    check "exclude_reblogs=true" in path
    check "min_id=456" in path

  test "local and remote filters are mutually exclusive":
    expect ValueError:
      discard publicTimelinePath(local = true, remote = true)


suite "fedi errors":
  test "preserves status and retry delay":
    let error = newFediError(Http429, %*{"error": "rate limited"}, 1500)
    check error.responseCode == Http429
    check error.retryAfterMs == 1500
    check error.info["error"].getStr == "rate limited"
