#!/usr/bin/env coffee
# http://code.tutsplus.com/tutorials/better-coffeescript-testing-with-mocha--net-24696
# mocha -w --watch-extensions coffee --compilers coffee:coffee-script/register

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
  it 'should understand -5m', ->
    bc.getRelativeTime('-5m').format('HH:mm').should.equal('11:55')
  it 'should understand -5h', ->
    bc.getRelativeTime('-5h').format('HH:mm').should.equal('07:00')
  it 'should understand -1d', ->
    bc.getRelativeTime('-1d').format('YYYY-MM-DD').should.equal('2015-12-31')
  it 'should understand yyyy-mm-dd', ->
    bc.getRelativeTime('2016-02-22').format('YYYY-MM-DD').should.equal('2016-02-22')
  it 'should understand hh:mm', ->
    bc.getRelativeTime('11:30').format('HH:mm').should.equal('11:30')
  
describe 'parseCommand', ->
  describe 'temporary notes', ->
    it 'should save time and command', ->
      p = bc.parseCommand('save nursed left side', {user: 'sacha'})
      p.should.have.property('function', bc.saveNote)
      p.should.have.property('value').that.eql({body: 'nursed left side'})
      p.time.format('YYYY-MM-DD HH:mm').should.equal('2016-01-01 12:00')
    it 'should save json', ->
      p = bc.parseCommand('save {"body": "nursed left side"}', {user: 'sacha'})
      p.should.have.property('function', bc.saveNote)
      p.should.have.property('value').that.eql({body: 'nursed left side'})
      p.time.format('YYYY-MM-DD HH:mm').should.equal('2016-01-01 12:00')
    it 'should load time and command', ->
      bc.executeCommand('save nursed left side', {user: 'sacha'}).then () =>
        bc.executeCommand('load', {user: 'sacha'}).then (p) =>
          p.should.have.property('value').that.eql({"body": "nursed left side"})
          moment(p.time).format('YYYY-MM-DD HH:mm').should.equal('2016-01-01 12:00')
    it 'should clear', ->
      bc.executeCommand('save nursed left side', {user: 'sacha'}).then () =>
        bc.executeCommand('clear', {user: 'sacha'})
      .then () =>
        bc.executeCommand('load', {user: 'sacha'})
      .then (data) =>
        data.should.eql({})
  describe 'activity', ->
    it 'should understand activities', ->
      p = bc.parseCommand('activity note A is having a bath', {})
      p.should.have.property('function', bc.logActivity)
      p.should.have.property('body', 'A is having a bath')
  describe 'mood', ->
    it 'should understand the mood', ->
      p = bc.parseCommand('mood is crying', {})
      p.should.have.property('title').that.matches(/crying/)
      p = bc.parseCommand('calm', {})
      p.should.have.property('title').that.matches(/calm/)
    it 'should understand relative time', ->
      p = bc.parseCommand('crying 5 minutes ago', {})
      p.should.have.property('title').that.matches(/crying/)
      p.startTime.format('HH:mm').should.equal('11:55')
  describe 'nurse', ->
    it 'should understand which side', ->
      p = bc.parseCommand('nursed left side for 10 minutes', {})
      p.should.have.property('left', 10)
      p.should.have.property('lastSide', 'left')
      p = bc.parseCommand('nursed right side for 10 minutes', {})
      p.should.have.property('right', 10)
      p.should.have.property('lastSide', 'right')
      p = bc.parseCommand('nursed left side for 10 minutes and right side for 5 minutes', {})
      p.should.have.property('left', 10)
      p.should.have.property('right', 5)
      p.should.have.property('lastSide', 'right')
      p = bc.parseCommand('nursed right side for 10 minutes and left side for 5 minutes', {})
      p.should.have.property('right', 10)
      p.should.have.property('left', 5)
      p.should.have.property('lastSide', 'left')
    it 'should understand relative time start', ->
      p = bc.parseCommand('nursed left side for 10 minutes', {})
      p.endTime.format('HH:mm').should.equal('12:00')
      p.startTime.format('HH:mm').should.equal('11:50')
    it 'should understand relative time end', ->
      p = bc.parseCommand('nursed left side for 10 minutes 5 minutes ago', {})
      p.endTime.format('HH:mm').should.equal('11:55')
      p.startTime.format('HH:mm').should.equal('11:45')
    it 'should understand relative time start', ->
      p = bc.parseCommand('nursed left side for 10 minutes starting 2016-02-01 14:00', {})
      p.startTime.format('HH:mm').should.equal('14:00')
      p.endTime.format('HH:mm').should.equal('14:10')
    it 'should understand relative time end when time is specified', ->
      p = bc.parseCommand('nursed left side for 10 minutes ending 2016-02-01 14:00', {})
      p.startTime.format('HH:mm').should.equal('13:50')
      p.endTime.format('HH:mm').should.equal('14:00')
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
      p.should.have.property('body').that.matches(/changed to disposable/)


