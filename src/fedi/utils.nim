import std/[strformat, strutils, uri]


type
  QueryParam* = tuple[key: string, value: string]


proc addQueryParam*(params: var seq[QueryParam], key, value: string) =
  if value.len > 0:
    params.add((key: key, value: value))


proc addQueryParam*(params: var seq[QueryParam], key: string, value: int) =
  if value > 0:
    params.add((key: key, value: $value))


proc addQueryParam*(params: var seq[QueryParam], key: string, value: bool) =
  if value:
    params.add((key: key, value: "true"))


proc buildQuery*(params: openArray[QueryParam]): string =
  if params.len > 0:
    result = "?" & encodeQuery(params)


proc splitAccount*(account: string): tuple[username: string, domain: string] =
  var normalized = account.strip()
  if normalized.len > 0 and normalized[0] == '@':
    normalized.delete(0, 0)

  let separator = normalized.rfind('@')
  if separator <= 0 or separator >= normalized.high:
    raise newException(ValueError, "account must be username@domain")

  result.username = normalized[0 ..< separator]
  result.domain = normalized[separator + 1 .. ^1]


proc webfingerUser*(account: string, scheme = "https"): string =
  let parsed = splitAccount(account)
  let resource = "acct:" & parsed.username & "@" & parsed.domain
  let query = buildQuery(@[(key: "resource", value: resource)])
  result = fmt"{scheme}://{parsed.domain}/.well-known/webfinger{query}"
