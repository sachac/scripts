#!/usr/bin/env coffee

rp = require 'request-promise'
subreddit = if process.argv.length >= 3 then process.argv[2] else 'emacs'
dateThreshold = if process.argv.length >= 4 then process.argv[3]

rp('http://reddit.com/r/' + subreddit + '/new.json?limit=50').then (body) -> 
  data = JSON.parse(body)
  for item in data.data.children
    date = new Date(item.data.created * 1000)
    if dateThreshold and date.toISOString() < dateThreshold
      continue
    if item.data.url.match 'https://www.reddit.com'
      console.log "- [[#{item.data.url}][#{item.data.title}]]"
    else
      console.log "- [[#{item.data.url}][#{item.data.title}]] ([[https://www.reddit.com#{item.data.permalink}][Reddit]])"


