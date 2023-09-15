import json
import asyncdispatch
import httpclient
import strformat
import httpCore
import times
import strutils
import os
import client

# NOTE it should only be https, but i dont care. Use with your own risk.
func webfingerUser*(username: string, scheme: string): string =
  let data = username.split("@")
  result = fmt"{scheme}://{data[1]}/.well-known/webfinger?resource={username}"
