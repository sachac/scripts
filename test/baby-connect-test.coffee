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
  it 'should understand yesterday', ->
    bc.getRelativeTime('yesterday').format('YYYY-MM-DD').should.equal('2015-12-31')
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
    it 'should allow side to be optional', ->
      p = bc.parseCommand('nursed from 12:00 to 12:10', {})
      p.should.have.property('left', 5)
      p.should.have.property('right', 5)
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
    it 'should understand time span', ->
      p = bc.parseCommand('nursed left side from 12:10 to 12:20', {})
      p.startTime.format('HH:mm').should.equal('12:10')
      p.endTime.format('HH:mm').should.equal('12:20')
      p.should.have.property('left', 10)
  describe 'update month', ->
    it 'should understand last month', ->
      p = bc.parseCommand('update last month', {})
      p.time.format('YYYY-MM-DD').should.equal('2015-12-01')
  describe 'update week', ->
    it 'should understand last week', ->
      p = bc.parseCommand('update last week', {})
      p.time.format('YYYY-MM-DD').should.equal('2015-12-26')
      p.should.have.property('span', 'week')
  describe 'update day', ->
    it 'should understand yesterday', ->
      p = bc.parseCommand('update yesterday', {})
      p.time.format('YYYY-MM-DD').should.equal('2015-12-31')
    it 'should understand today', ->
      p = bc.parseCommand('update today', {})
      p.time.format('YYYY-MM-DD').should.equal('2016-01-01')
    it 'should understand specified date', ->
      p = bc.parseCommand('update date 2015-06-06', {})
      p.time.format('YYYY-MM-DD').should.equal('2015-06-06')
  describe 'log potty', ->
    it 'should use the right function', ->
      p = bc.parseCommand('potty note Pee, Pad, Read, Accompanied', {})
      p.should.have.property('function', bc.logPotty)
    it 'should capture note', ->
      p = bc.parseCommand('potty note Pee, Pad, Read, Accompanied', {})
      p.should.have.property('body').that.matches(/Pee, Pad, Read, Accompanied/)
  describe 'log solids', ->
    it 'should use the right function', ->
      p = bc.parseCommand('ate 2 tsp of sweet potato', {})
      p.should.have.property('function', bc.logSolids)
    it 'should capture notes', ->
      p = bc.parseCommand('ate 2 tsp of sweet potato', {})
      p.should.have.property('body').that.matches(/sweet potato/)
      p.should.have.property('body').that.matches(/2 tsp/)
  describe 'log supplement', ->
    it 'should use the right function', ->
      p = bc.parseCommand('drank 0.25 oz of Milk', {})
      p.should.have.property('function', bc.logSupplement)
    it 'should capture quantity', ->
      p = bc.parseCommand('drank 0.25 oz of Milk', {})
      p.should.have.property('quantity', 0.25)
      p = bc.parseCommand('drank 0.50 oz of Milk', {})
      p.should.have.property('quantity', 0.5)
    it 'should capture type', ->
      p = bc.parseCommand('drank 0.25 oz of Milk', {})
      p.should.have.property('type', 'Milk')
      p = bc.parseCommand('drank 0.25 oz of Formula', {})
      p.should.have.property('type', 'Formula')
    it 'should capture notes', ->
      p = bc.parseCommand('drank 0.25 oz of Milk note eyedropper', {})
      p.should.have.property('body').that.matches(/eyedropper/)
    it 'should capture duration', ->
      p = bc.parseCommand('drank 0.25 oz of Milk over 10 minutes', {})
      p.should.have.property('duration', 10)
    it 'should understand start and end times', ->
      p = bc.parseCommand('drank 0.25 oz of Milk from 9:00 to 9:30', {})
      p.should.have.property('duration', 30)
      p.startTime.format('H:mm').should.equal('9:00')
      p.endTime.format('H:mm').should.equal('9:30')
  describe 'log diaper', ->
    it 'should understand relative times', ->
      p = bc.parseCommand('wet diaper 5 minutes ago', {})
      p.time.format('HH:mm').should.equal('11:55')
      p = bc.parseCommand('BM diaper 10 minutes ago', {})
      p.time.format('HH:mm').should.equal('11:50')
    it 'should handle open air', ->
      p = bc.parseCommand('wet diaper open air', {})
      p.should.have.property('function', bc.logDiaper)
      p.should.have.property('type', 'wet')
      p.should.have.property('openAir', true)
    it 'should distinguish diaper types', ->
      p = bc.parseCommand('wet diaper', {})
      p.should.have.property('function', bc.logDiaper)
      p.should.have.property('type', 'wet')
      p = bc.parseCommand('BM diaper', {})
      p.should.have.property('function', bc.logDiaper)
      p.should.have.property('type', 'BM')
    it 'should save the note', ->
      p = bc.parseCommand('BM diaper note changed to disposable', {})
      p.should.have.property('function', bc.logDiaper)
      p.should.have.property('type', 'BM')
      p.should.have.property('body').that.matches(/changed to disposable/)
  describe 'log weight', ->
    it 'should set the function', ->
      p = bc.parseCommand('weighed 4.47 kg note pre-feed home', {})
      p.should.have.property('function', bc.logWeight)
    it 'should capture notes', ->
      p = bc.parseCommand('weighed 4.47 kg note pre-feed home', {})
      p.should.have.property('body').that.matches(/pre-feed home/)
    it 'should convert kg', ->
      p = bc.parseCommand('weighed 4.47 kg note pre-feed home', {})
      p.should.have.property('weight').closeTo(157.39, 0.1)
    it 'should convert lb and oz', ->
      p = bc.parseCommand('weighed 9 lbs 13 oz', {})
      p.should.have.property('weight').closeTo(157, 0.1)
    it 'should convert lb', ->
      p = bc.parseCommand('weighed 10 lbs', {})
      p.should.have.property('weight').closeTo(160, 0.1)
  describe 'log sleep', ->
    it 'should set the function', ->
      p = bc.parseCommand('slept from 14:00 to 14:30', {})
      p.should.have.property('function', bc.logSleep)
    it 'should get the start and end time', ->
      p = bc.parseCommand('slept from 14:00 to 14:30', {})
      p.time.format('HH:mm').should.equal('14:00')
      p.endTime.format('HH:mm').should.equal('14:30')
    
