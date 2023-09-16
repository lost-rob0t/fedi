import ../src/fedi
import json, os
import asyncdispatch
let a = newFediClient("https://mastodon.social")
try:
  echo $a.getTimeline
  echo $a.getAccountInfo("Gargron")
except FediError as e:
  echo e.info
