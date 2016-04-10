#!/usr/bin/env coffee

# Serve the current directory
auth = require 'http-auth'
secret = require '/home/sacha/.secret.js'
bodyParser = require 'body-parser'
basic = auth.basic({realm: "Sacha"}, (username, password, callback) ->
  callback(username == secret.auth.user && password == secret.auth.password)
)
express = require 'express'
app = express()
console.log process.argv
app.use auth.connect(basic)
app.use express.static(process.argv[2] || '.')
app.use bodyParser.urlencoded({extended: true})
app.use bodyParser.json()
if process.argv.length > 3
  app.all('/', (req, res, next) =>
    res.header("Access-Control-Allow-Origin", "*")
    res.header("Access-Control-Allow-Headers", "X-Requested-With")
    next()
  )
  app.use '/api', require(process.argv[3])
  
app.listen process.env.PORT || 3000, () ->
  console.log "Listening on " + (process.env.PORT || 3000)

