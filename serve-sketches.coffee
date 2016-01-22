#!/usr/bin/env coffee

SKETCH_DIR = '/home/sacha/sketches'
fs = require 'fs'
path = require 'path'
q = require 'q'

################################################################################
# Utility functions
getSketches = (dir) ->
  p = q.defer()
  fs.readdir dir, (err, files) ->
    p.resolve files.reverse()
  return p.promise

getRandomSketch = (sketches) ->
  index = Math.floor(sketches.length * Math.random())
  return sketches[index]

getSketchByID = (sketches, id) ->
  console.log id
  regexp = new RegExp('^' + id)
  console.log regexp
  if !id.match(/^[0-9]+/)
    return null
  for filename in sketches
    if filename.match regexp
      return filename

getSketchesByTags = (sketches, tags) ->
  list = []
  for filename in sketches
    match = true
    for tag in tags
      if !filename.match tag
        match = false
        break
    if match
      list.push filename
  return list

getSketchesByRef = (sketches, ref) ->
  if !ref.match /^[0-9]/
    return null
  regexp = new RegExp(" ref .*" + ref)
  return getSketchesByRegexp(sketches, regexp)
  
getSketchesByRegexp = (sketches, regexp) ->
  list = []
  for filename in sketches
    if filename.match regexp
      list.push filename
  return list

getWeeklySketchesForMonth = (year, month) ->
  # Show all the "Week ending yyyy-mm-dd where the week would have covered a day in the month"
  # TODO
  return null  

################################################################################
# Request handlers

header = """
<script src="https://cdnjs.cloudflare.com/ajax/libs/jquery/2.2.0/jquery.min.js"></script>
  <script src="https://npmcdn.com/imagesloaded@4.1/imagesloaded.pkgd.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/masonry/4.0.0/masonry.pkgd.min.js"></script>
<a href="/random">Random</a> - <a href="/tag/monthly">Monthly</a><br />
         """
footer = """
<a href="/random">Random</a> - <a href="/tag/monthly">Monthly</a><br />
  <script>$('.grid').imagesLoaded(function() { $('.grid').masonry({itemSelector: '.grid-item'}); })</script>
"""

linkTags = (filename) ->
  return filename.replace(/#([-a-zA-Z]+)/g, (x, tag) ->
    return '<a href="/tag/' + tag + '">' + x + '</a>'
  )
    
linkToImage = (filename, optionalURL) ->
  url = '/image/' + encodeURIComponent(filename)
  s = '<div class="grid-item"><a href="' + (optionalURL || url) + '"><img src="' + url + '" width="100%"></a>'
  s += '<br />' + linkTags(filename) + '</div>'
  return s
  
serveRandomImage = (req, res) ->
  getSketches(SKETCH_DIR).then (sketches) ->
    list = []
    nonJournal = sketches.filter (s) ->
      return !s.match(/#journal/)
    for i in [1..6]
      list.push getRandomSketch(nonJournal)
    res.header "Cache-Control", "no-cache, no-store, must-revalidate"
    res.header "Pragma", "no-cache"
    res.header "Expires", 0
    res.send header + formatList(list) + footer

serveImageByID = (req, res) ->
  getSketches(SKETCH_DIR).then (sketches) ->
    filename = getSketchByID(sketches, req.params.id)
    res.send header + linkToImage(filename) + footer

serveImageByName = (req, res) ->
  filename = SKETCH_DIR + '/' + req.params.filename
  res.sendFile filename

formatList = (list, urlFunc, size) ->
  return '<style type="text/css">.grid-item { width: ' + (size || '50%') + ' }</style><div class="grid">' + (list.map((s) ->
    return linkToImage(s, (if urlFunc then urlFunc(s) else null), size)
  ).join '') + '</div>'
  
serveImagesByTag = (req, res) ->
  tag = req.params.tag.split(/,/g)
  page = ''
  getSketches(SKETCH_DIR).then (sketches) ->
    q(getSketchesByTags(sketches, tag)).then (list) ->
      res.send header + formatList(list) + footer

serveImagesByDate = (req, res) ->
  getSketches(SKETCH_DIR).then (sketches) ->
    base = '/date/' + req.params.year
    if req.params.month
      regexp = new RegExp('^' + req.params.year + '-' + req.params.month + '.* #journal[ \.]')
      urlFunc = null
    else if req.params.year
      regexp = new RegExp(req.params.year + ' .*#monthly')
      months = ['Jan', 'Feb', 'March', 'Apr', 'May', 'June', 'July', 'Aug', 'Sept', 'Oct', 'Nov', 'Dec']
      urlFunc = (s) ->
        for month, i in months
          if s.match(month)
            if i + 1 < 10
              return base + '/0' + (i + 1)
            else
              return base + '/' + (i + 1)
    list = getSketchesByRegexp(sketches, regexp).reverse()
    res.send header + formatList(list, urlFunc, '33%') + footer
      
  
################################################################################
# Express

express = require 'express'
app = express()
app.get '/random', serveRandomImage
app.get '/id/:id', serveImageByID
app.get '/image/:filename', serveImageByName
app.get '/tag/:tag', serveImagesByTag
app.get '/date/:year/:month?', serveImagesByDate

app.listen process.env.PORT || 3000, () ->
  console.log "Listening on " + (process.env.PORT || 3000)
