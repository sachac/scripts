#!/usr/bin/env coffee
# http://code.tutsplus.com/tutorials/better-coffeescript-testing-with-mocha--net-24696
# mocha --compilers coffee:coffee-script/register

bc = require('../baby-connect')
chai = require 'chai'
chai.should()
tk = require('timekeeper')
moment = require('moment')

time = new Date('2016-01-01 12:00 PM EST')
tk.freeze(time)

describe 'getRelativeTime', ->
  it 'should understand last week', ->
    bc.getRelativeTime('last week').format('YYYY-MM-DD').should.equal('2015-12-26')
  it 'should understand 1 week ago', ->
    bc.getRelativeTime('1 week ago').format('YYYY-MM-DD').should.equal('2015-12-26')
  it 'should understand 2 weeks ago', ->
    bc.getRelativeTime('2 weeks ago').format('YYYY-MM-DD').should.equal('2015-12-19')
  it 'should understand last month', ->
    bc.getRelativeTime('last month').format('YYYY-MM-DD').should.equal('2015-12-01')
  it 'should understand 2 months ago', ->
    bc.getRelativeTime('2 months ago').format('YYYY-MM-DD').should.equal('2015-11-01')
  it 'should understand 5 minutes ago', ->
    bc.getRelativeTime('5 minutes ago').format('HH:mm').should.equal('11:55')
  it 'should understand 5 hours ago', ->
    bc.getRelativeTime('5 hours ago').format('HH:mm').should.equal('07:00')
    
describe 'parseCommand', ->
  describe 'update month', ->
    it 'should understand last month', ->
      p = bc.parseCommand('update last month', {})
      p.time.format('YYYY-MM-DD').should.equal('2015-12-01')
  describe 'update week', ->
    it 'should understand last week', ->
      p = bc.parseCommand('update last week', {})
      p.time.format('YYYY-MM-DD').should.equal('2015-12-26')
  describe 'log diaper', ->
    it 'should understand relative times', ->
      p = bc.parseCommand('peed 5 minutes ago', {})
      p.time.format('HH:mm').should.equal('11:55')
      p = bc.parseCommand('pooed 10 minutes ago', {})
      p.time.format('HH:mm').should.equal('11:50')
    it 'should distinguish diaper types', ->
      p = bc.parseCommand('wet diaper', {})
      p.should.have.property('function', bc.logDiaper)
      p.should.have.property('type', 'wet')
      p = bc.parseCommand('pee', {})
      p.should.have.property('function', bc.logDiaper)
      p.should.have.property('type', 'wet')
      p = bc.parseCommand('poo', {})
      p.should.have.property('function', bc.logDiaper)
      p.should.have.property('type', 'BM')
      p = bc.parseCommand('BM diaper', {})
      p.should.have.property('function', bc.logDiaper)
      p.should.have.property('type', 'BM')
    it 'should save the note', ->
      p = bc.parseCommand('BM diaper note changed to disposable', {})
      p.should.have.property('function', bc.logDiaper)
      p.should.have.property('type', 'BM')
      p.should.have.property('note').that.matches(/changed to disposable/)


