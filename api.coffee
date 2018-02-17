express = require 'express'
router = express.Router()
sqlite3 = require('sqlite3').verbose()
babyconnect = require './baby-connect'
config = require(require('home-dir')() + '/.secret')
moment = require 'moment'
q = require 'q'
DB_FILE = '/home/sacha/Dropbox/apps/babyconnect.db'

babyConnectProcessor = (req, res) =>
  s = if req.body && req.body.s then req.body.s else req.query.s
  params = {child: config.babyConnect.kids.main, user: req.user}
  babyconnect.parseCommand(s, params)
  db = new sqlite3.Database(DB_FILE)
  db.run('INSERT INTO log (time, text, parsed) VALUES (?, ?, ?)',
    [new Date(), s, JSON.stringify(params)], () =>
      db.close()
      if params.function
        q(params.function(params)).then((data) =>
          res.send data
        )
      else
        res.send 'Unknown command: ' + s
      )

router.all '/s', (req, res) =>
  babyConnectProcessor(req, res)
router.all '/logs', (req, res) =>
  babyconnect.getLogs(req.query).then (data) =>
    res.send(data)
router.get '/babyconnect/data.csv', (req, res) =>
  babyconnect.convertToCSV(req.query).then (data) =>
    res.send(data)
router.post '/babyconnect/update', (req, res) =>
  child = config.babyConnect.kids.main
  q(babyconnect.update({child: child, span: 'week'})).then () =>
    res.sendStatus(200)
    
router.get '/videos', (req, res) =>
  exec = require('child_process').exec
  cmd = 'node /home/sacha/bin/stalk-library-videos.js /home/sacha/Dropbox/apps/stalk-library-videos.json';
  csv = require 'fast-csv'
  exec(cmd, (error, stdout, stderr) =>
    s = ''
    table = csv.fromString(stdout)
    .on('data', (data) =>
      s += '<tr><td>' + data.join('</td><td>') + '</td></tr>'
    )
    .on('end', () => res.send('<table>' + s + '</table>'))
  )  

serveIndex = require('serve-index')
router.use '/agenda', express.static('/home/sacha/cloud/agenda'), serveIndex('/home/sacha/cloud/agenda', {'icons': true})
  
  
module.exports = router
