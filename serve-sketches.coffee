#!/usr/bin/env coffee

SKETCH_DIR = '/home/sacha/sketches'
fs = require 'fs'
path = require 'path'
q = require 'q'
auth = require 'http-auth'
secret = require '/home/sacha/.secret.js'
_ = require 'lodash'

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
<div class="links"><a href="<%= base %>/random">Random</a> - <a href="<%= base %>/date/2015">2015</a> - <a href="<%= base %>/date/2016">2016</a> - <a href="<%= base %>/tag">Tags by freq</a> -
<a href="<%= base %>/tag?sort=alpha">Tags by alpha</a> - <a href="<%= base %>/nonjournal">Nonjournal</a> - <a href="<%= base %>/journal">Journal</a></div>
"""
header = _.template("""
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
        $.ajax({method: 'POST', url: '<%= base %>/followup/' + encodeURIComponent(filename)});
      });
    });
  </script>
  """ + links)
footer = _.template(links)
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
    
linkToImage = (base, filename, optionalURL) ->
  url = base + '/image/' + encodeURIComponent(filename)
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
    s = header(req.app.locals.templateVars) + formatList(req, list) + footer(req.app.locals.templateVars) + masonry
    res.send s
exports.serveRandomImage = serveRandomImage

showTextList = (req, res, filter) ->
  getSketches(SKETCH_DIR).then (sketches) ->
    list = sketches.filter(filter)
    res.send header(req.app.locals.templateVars) + '<ul>' + list.map((filename) ->
      url = req.app.locals.base + '/image/' + encodeURIComponent(filename)
      return '<li><a href="' + url + '">View</a> - ' + linkTags(filename) + '</li>'
    ).join('') + '</ul>' + footer(req.app.locals.templateVars)
exports.showTextList = showTextList
  
listNonjournalSketches = (req, res) ->
  showTextList(req, res, (s) ->
    return !s.match(/#journal/) && s.match(/^[0-9]/)
  )
exports.listNonjournalSketches = listNonjournalSketches
    
listJournalSketches = (req, res) ->
  showTextList(req, res, (s) ->
    return s.match(/#journal|#monthly|#yearly/)
  )
exports.listJournalSketches = listJournalSketches

serveImageByID = (req, res) ->
  getSketches(SKETCH_DIR).then (sketches) ->
    filename = getSketchByID(sketches, req.params.id)
    res.send header(req.app.locals.templateVars) + linkToImage(req.app.path(), req.filename) + footer(req.app.locals.templateVars)
exports.serveImageByID = serveImageByID

serveImageByName = (req, res) ->
  filename = SKETCH_DIR + '/' + req.params.filename
  res.sendFile filename
exports.serveImageByName = serveImageByName

formatList = (req, list, urlFunc, size = '50%') ->
  return '<style type="text/css">.grid-item { width: ' + size + '; float: left; margin-bottom: 1em }</style><div class="grid">' + (list.map((s, index) ->
    html = linkToImage(req.app.locals.base, s, (if urlFunc then urlFunc(s) else null))
    if ((size == "33%" && index % 3 == 2) || (size == "50%" && index % 2 == 1))
      html += '<br clear="both" />'
    return html
  ).join '') + '</div>'
exports.formatList = formatList

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
exports.countTags = countTags
    
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
    res.send header(req.app.locals.templateVars) + '<ul>' + tags.map((tagInfo) ->
      return '<li><a href="/tag/' + tagInfo[0] + '">' + tagInfo[0] + ' (' + tagInfo[1] + ')</a></li>'
    ).join('') + '</ul>' + footer(req.app.locals.templateVars)
exports.serveTagList = serveTagList

followUp = (req, res) ->
  filename = req.params.filename.replace(/["'\\]/, '') # a little bit of cleaning; probably should require auth
  command = 'emacsclient --eval \'(my/follow-up-on-sketch "' + filename + '")\''
  require('child_process').exec(command)
  res.status(200)
exports.followUp = followUp
  
serveImagesByTag = (req, res) ->
  tag = req.params.tag.split(/,/g)
  page = ''
  getSketches(SKETCH_DIR).then (sketches) ->
    q(getSketchesByTags(sketches, tag)).then (list) ->
      res.send header(req.app.locals.templateVars) + formatList(req, list) + footer(req.app.locals.templateVars)
exports.serveImagesByTag = serveImagesByTag

showSketchesByRange = (req, res) ->
  start = req.query.start
  end = req.query.end
  getSketches(SKETCH_DIR).then (sketches) ->
    inRange = sketches.filter (x) ->
      return x >= start && (!end || x <= end)
    res.send header(req.app.locals.templateVars) + formatList(req, inRange) + footer(req.app.locals.templateVars)
exports.showSketchesByRange = showSketchesByRange

serveImagesByDate = (req, res) ->
  getSketches(SKETCH_DIR).then (sketches) ->
    base = req.app.locals.base + '/date/' + req.params.year
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
    res.send header(req.app.locals.templateVars) + formatList(req, list, urlFunc, '33%') + footer(req.app.locals.templateVars)
exports.serveImagesByDate = serveImagesByDate

################################################################################
# Express

setupServer = (base, authentication) =>
  express = require 'express'
  app = express()
  app.locals.base = base
  app.locals.templateVars = {base: base}
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
  if authentication
    app.use '/followup/:filename', auth.connect(authentication)  
    app.post '/followup/:filename', followUp
  app
exports.setupServer = setupServer

if require.main == module
  basic = auth.basic({realm: "Sketches"}, (username, password, callback) ->
    callback(username == secret.auth.user && password == secret.auth.password)
  )
  app = setupServer('', basic)
  app.listen process.env.PORT || 3000, () ->
    console.log "Listening on " + (process.env.PORT || 3000)
