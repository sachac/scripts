#!/usr/bin/env coffee

SKETCH_DIR = '/home/sacha/sketches'
fs = require 'fs'
path = require 'path'
q = require 'q'
auth = require 'http-auth'
secret = require '/home/sacha/.secret.js'

basic = auth.basic({realm: "Sketches"}, (username, password, callback) ->
  callback(username == secret.auth.user && password == secret.auth.password)
)
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
  regexp = new RegExp('^' + id)
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
      regex = new RegExp('#' + tag + '[ \.]')
      if !filename.match regex
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

links = """
<div class="links"><a href="/random">Random</a> - <a href="/date/2015">2015</a> - <a href="/date/2016">2016</a> - <a href="/tag">Tags by freq</a> -
<a href="/tag?sort=alpha">Tags by alpha</a> - <a href="/nonjournal">Nonjournal</a> - <a href="/journal">Journal</a></div>
"""
header = """
<style type="text/css">body { font-family: Arial, sans-serif; }
ul li { margin-bottom: 0.5em }
.links { font-size: large; margin-top: 1em; margin-bottom: 1em; clear: both }</style>
<script src="https://cdnjs.cloudflare.com/ajax/libs/jquery/2.2.0/jquery.min.js"></script>
  <script src="https://npmcdn.com/imagesloaded@4.1/imagesloaded.pkgd.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/masonry/4.0.0/masonry.pkgd.min.js"></script>
  <script>
    $(document).ready(function() {
      $('.followup').click(function() {
        filename = $(this).closest('.grid-item').attr('data-filename');
        $.ajax({method: 'POST', url: '/followup/' + encodeURIComponent(filename)});
      });
    });
  </script>
  """ + links 
footer = links
masonry = "<script>$('.grid').imagesLoaded(function() { $('.grid').masonry({itemSelector: '.grid-item'}); })</script>"

linkTags = (filename) ->
  filename = filename.replace(/#([-a-zA-Z]+)/g, (x, tag) ->
    return '<a href="/tag/' + tag + '">' + x + '</a>'
  )
  filename = filename.replace(/ref .*/, (x) ->
    return x.replace(/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9][a-z]?/, (y) ->
      return '<a href="/id/' + y + '">' + y + '</a>'
    )
  )
  return filename
    
linkToImage = (filename, optionalURL) ->
  url = '/image/' + encodeURIComponent(filename)
  s = '<div class="grid-item" data-filename="' + filename + '"><a href="' + (optionalURL || url) + '"><img src="' + url + '" width="100%"></a>'
  s += '<br />' + linkTags(filename) + '<br /><a href="#" class="followup">Follow up</a></div>'
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
    res.send header + formatList(list) + footer + masonry

showTextList = (req, res, filter) ->
  getSketches(SKETCH_DIR).then (sketches) ->
    list = sketches.filter(filter)
    res.send header + '<ul>' + list.map((filename) ->
      url = '/image/' + encodeURIComponent(filename)
      return '<li><a href="' + url + '">View</a> - ' + linkTags(filename) + '</li>'
    ).join('') + '</ul>' + footer
  
listNonjournalSketches = (req, res) ->
  showTextList(req, res, (s) ->
    return !s.match(/#journal/) && s.match(/^[0-9]/)
  )
    
listJournalSketches = (req, res) ->
  showTextList(req, res, (s) ->
    return s.match(/#journal|#monthly|#yearly/)
  )

serveImageByID = (req, res) ->
  getSketches(SKETCH_DIR).then (sketches) ->
    filename = getSketchByID(sketches, req.params.id)
    res.send header + linkToImage(filename) + footer

serveImageByName = (req, res) ->
  filename = SKETCH_DIR + '/' + req.params.filename
  res.sendFile filename

formatList = (list, urlFunc, size) ->
  size ||= '50%'
  return '<style type="text/css">.grid-item { width: ' + size + '; float: left; margin-bottom: 1em }</style><div class="grid">' + (list.map((s, index) ->
    html = linkToImage(s, (if urlFunc then urlFunc(s) else null), size)
    if ((size == "33%" && index % 3 == 2) || (size == "50%" && index % 2 == 1))
      html += '<br clear="both" />'
    return html
  ).join '') + '</div>'

countTags = (sketches) ->
  tags = {}
  regexp = /#([-a-zA-Z]+)/g
  sketches.map (s) ->
    while true
      m = regexp.exec(s)
      if !m then break
      tags[m[1]] ||= 0
      tags[m[1]]++
  list = ([key, val] for own key, val of tags)
  return list.sort (a, b) ->
    return b[1] - a[1]
    
serveTagList = (req, res) ->
  getSketches(SKETCH_DIR).then (sketches) ->
    nonJournal = sketches.filter((s) ->
      return !s.match(/#journal/)
    )
    tags = countTags(nonJournal)
    if req.query.sort == 'alpha'
      tags = tags.sort (a, b) ->
        return -1 if a[0] < b[0]
        return 1 if a[0] > b[0]
        return 0
    res.send header + '<ul>' + tags.map((tagInfo) ->
      return '<li><a href="/tag/' + tagInfo[0] + '">' + tagInfo[0] + ' (' + tagInfo[1] + ')</a></li>'
    ).join('') + '</ul>' + footer

followUp = (req, res) ->
  filename = req.params.filename.replace(/["'\\]/, '') # a little bit of cleaning; probably should require auth
  command = 'emacsclient --eval \'(my/follow-up-on-sketch "' + filename + '")\''
  require('child_process').exec(command)
  res.status(200)
  
serveImagesByTag = (req, res) ->
  tag = req.params.tag.split(/,/g)
  page = ''
  getSketches(SKETCH_DIR).then (sketches) ->
    q(getSketchesByTags(sketches, tag)).then (list) ->
      res.send header + formatList(list) + footer

showSketchesByRange = (req, res) ->
  start = req.query.start
  end = req.query.end
  getSketches(SKETCH_DIR).then (sketches) ->
    inRange = sketches.filter (x) ->
      return x >= start && (!end || x <= end)
    res.send header + formatList(inRange) + footer

serveImagesByDate = (req, res) ->
  getSketches(SKETCH_DIR).then (sketches) ->
    base = '/date/' + req.params.year
    if req.params.month
      regexp = new RegExp('^' + req.params.year + '-' + req.params.month + '.*')
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
app.use '/followup/:filename', auth.connect(basic)  
app.get '/random', serveRandomImage
app.get '/id/:id', serveImageByID
app.get '/image/:filename', serveImageByName
app.get '/tag', serveTagList
app.get '/tag/:tag', serveImagesByTag
app.get '/date/:year/:month?', serveImagesByDate
app.get '/nonjournal', listNonjournalSketches
app.get '/journal', listJournalSketches
app.get '/range', showSketchesByRange
app.get '/', serveRandomImage
app.post '/followup/:filename', followUp
app.listen process.env.PORT || 3000, () ->
  console.log "Listening on " + (process.env.PORT || 3000)
