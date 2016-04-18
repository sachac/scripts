express = require 'express'
router = express.Router()
sqlite3 = require('sqlite3').verbose()
babyconnect = require './baby-connect'
config = require(require('home-dir')() + '/.secret')
moment = require 'moment'
q = require 'q'

babyConnectProcessor = (req, res) =>
  s = if req.body && req.body.s then req.body.s else req.query.s
  params = {child: config.babyConnect.kids.main}
  babyconnect.parseCommand(s, params)
  if params.function
    q(params.function(params)).then((data) =>
      res.send data
    )
  else
    res.send 'Unknown command: ' + s

router.get '/s', (req, res) =>
  babyConnectProcessor(req, res)
router.post '/s', (req, res) =>
  babyConnectProcessor(req, res)
  
router.get '/babyconnect/data.csv', (req, res) =>
  babyconnect.convertToCSV().then (data) =>
    res.send(data)
router.post '/babyconnect/update', (req, res) =>
  child = config.babyConnect.kids.main
  q(babyconnect.update({child: child, span: 'week'})).then () =>
    res.sendStatus(200)

module.exports = router
