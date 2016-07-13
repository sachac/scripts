#!/usr/bin/env coffee

config = require(require('home-dir')() + '/.secret')
fs = require 'fs'
rp = require('request-promise')
q = require 'q'
csv = require 'fast-csv'
moment = require 'moment'
cheerio = require('cheerio')
split = require('split')
sqlite3 = require('sqlite3').verbose()
program = require('commander')
_ = require('lodash')

DATA_FILE = '/home/sacha/Dropbox/apps/data.csv'
DB_FILE = '/home/sacha/Dropbox/apps/babyconnect.db'

makeBabyConnectRequest = (requestData) =>
  requestData.jar = true
  requestData.followRedirect = true
  requestData.followAllRedirects = true
  return rp(requestData).then((x) =>
    if JSON.parse(x).Code == 401
      login().then(() =>
        rp(requestData)
      )
    else
      x
  )
  
login = () =>
  return rp({
    jar: true, followRedirect: true, followAllRedirects: true,
    url: 'https://www.baby-connect.com/Cmd?cmd=UserAuth',
    method: 'POST',
    form: {email: config.babyConnect.email, pass: config.babyConnect.password}
  })

getTSForDay = (date) =>
  moment(date).format('YYMMDD')

# params: child, time
getBabyConnectSummary = (params) =>
  formData = {Kid: params.child.id, pdt: getTSForDay(params.time)}
  requestData = {
    url: 'https://www.baby-connect.com/CmdW?cmd=KidGetSummary',
    method: 'POST',
    form: formData
  }
  makeBabyConnectRequest(requestData).then((x) =>
    JSON.parse x
  )

# params: time, child
retrieveDay = (params) =>
  # date: m/dd/yyyy, gets the last 7 days
  startDate = moment(params.time).format('MM/DD/YYYY')
  makeBabyConnectRequest({
    url: 'http://www.baby-connect.com/GetCmd?cmd=StatusExport&kid=' + params.child.id+ '&exportType=0&dt=' + startDate
  })

# params: time, child
retrieveWeek = (params) =>
  # date: m/dd/yyyy, gets the last 7 days
  startDate = moment(params.time).format('MM/DD/YYYY')
  makeBabyConnectRequest({
    url: 'http://www.baby-connect.com/GetCmd?cmd=StatusExport&kid=' + params.child.id+ '&exportType=1&dt=' + startDate
  })
exports.retrieveWeek = retrieveWeek

# params: date, child
retrieveMonth = (params) =>
  # gets the current month
  startDate = moment(params.time).startOf('month').format('MM/DD/YYYY')
  makeBabyConnectRequest({
    url: 'http://www.baby-connect.com/GetCmd?cmd=StatusExport&kid=' + params.child.id + '&exportType=2&dt=' + startDate
  })
exports.retrieveMonth = retrieveMonth

logStatus = (form) =>
  makeBabyConnectRequest({
    url: 'https://www.baby-connect.com/CmdPostW?cmd=StatusPost',
    method: 'POST',
    form: form})
exports.logStatus = logStatus

# params: child, time, left (mins), right (mins), lastSide (left|right)
logNurse = (params) =>
  if !params.endTime
    params.endTime = params.time.clone().add((+params.left || 0) + (+params.right || 0), 'minutes')
  if !params.lastSide
    params.lastSide = if params.left then 'left' else 'right'
  label = params.child.name + ' nursed ('
  if params.lastSide == 'left'
    label = label + (if params.right then (+params.right || 0) + 'min right, ' else '')
    label = label + (+params.left || 0) + 'min left'
  else
    label = label + (if params.left then (+params.left || 0) + 'min left, ' else '')
    label = label + (+params.right || 0) + 'min right'
  label = label + ')'
  db = new sqlite3.Database(DB_FILE)
  p = q.defer()
  db.run('INSERT INTO data (startTime, endTime, activity, duration, label) VALUES (?, ?, ?, ?, ?)',
    [params.time.toDate(), params.endTime.toDate(), 'Nursing', (params.left || 0) + (params.right || 0), label], () =>
      db.close()
      p.resolve(logStatus({
        Kid: params.child.id,
        C: 350,
        uts: params.time.format('HHmm'),
        ptm: params.time.format('HHmm'),
        pdt: getTSForDay(params.time)
        d: (+params.left || 0) + (+params.right || 0),
        e: params.endTime.format('M/DD/YYYY HH:mm'),
        n: params.body,
        txt: label + (if params.text then ' - ' + params.text else ''),
        isst: 1,
        p: (if params.lastSide == 'left' then 1 else 2) + ';' + (+params.left || 0) + ';' + (+params.right || 0),
        listKid: -1
      })))
  p.promise
exports.logNurse = logNurse

# params: child, time, body
logSolids = (params) =>
  label = params.child.name + ' ' + params.body
  logStatus({
    Kid: params.child.id,
    C: 200,
    uts: params.time.format('HHmm'),
    ptm: params.time.format('HHmm'),
    pdt: getTSForDay(params.time),
    n: params.body,
    txt: label,
    isst: 1,
    listKid: -1
  })
exports.logSolids = logSolids

# params: child, time, type, quantity
logSupplement = (params) =>
  label = params.child.name + ' drank ' + params.quantity + ' oz of ' + params.type
  if params.endTime
    duration = params.endTime.diff(params.startTime, 'minutes')
  else
    duration = params.duration
    
  if duration
    label = label + ' (' + duration + 'min)'
  
  logStatus({
    Kid: params.child.id,
    C: 300,
    uts: params.time.format('HHmm'),
    ptm: params.time.format('HHmm'),
    pdt: getTSForDay(params.time),
    d: duration,
    e: if params.endTime then params.endTime.format('M/DD/YYYY HH:mm') end,
    n: params.body,
    txt: label + (if params.body then ' - ' + params.body else ''),
    p: params.quantity + ';oz;' + params.type,
    isst: 1,
    listKid: -1
  })
exports.logSupplement = logSupplement

# params: child, time, body
logPotty = (params) =>
  db = new sqlite3.Database(DB_FILE)
  p = q.defer()
  label = params.child.name + ': Potty'
  db.run('INSERT INTO data (startTime, endTime, activity, label, notes) VALUES (?, ?, ?, ?, ?)',
    [params.time.toDate(), params.time.toDate(), 'Potty', label, params.body], () =>
      db.close()
      p.resolve(logStatus({
        Kid: params.child.id,
        C: 2500,
        fmt: 'long',
        txt: label,
        n: params.body,
        uts: params.time.format('HHmm'),
        ptm: params.time.format('HHmm'),
        pdt: params.time.format('YYMMDD'),
        listKid: -1
      })))
  p.promise
exports.logPotty = logPotty

# params: child, type (BM | wet), time, text (optional), body,
# openAir
#
# open air: 0,1,,
# small, open air: 001,,
# medium, open air: 011,,
logDiaper = (params) =>
  typeCode = null
  if params.type.match(/BM/i) and params.type.match(/wet/)
    typeCode = '402'
  else if params.type.match(/BM/i)
    typeCode = '401'
  else if params.type.match(/wet/)
    typeCode = '403'
  options = '0,'
  if params.openAir
    options += '1,,'
  else
    options += '0,,'
  db = new sqlite3.Database(DB_FILE)
  p = q.defer()
  label = params.child.name + ' had a ' + (params.text || (params.type + ' diaper')) + (if params.body then ' ' + params.body else '')
  db.run('INSERT INTO data (startTime, endTime, activity, label, notes) VALUES (?, ?, ?, ?, ?)',
    [params.time.toDate(), params.time.toDate(), 'Diaper', label, params.body], () =>
      db.close()
      p.resolve(logStatus({
        Kid: params.child.id,
        C: typeCode,
        fmt: 'long',
        txt: label,
        n: params.body,
        uts: params.time.format('HHmm'),
        ptm: params.time.format('HHmm'),
        pdt: params.time.format('YYMMDD'),
        p: options,
        listKid: -1
      })))
  p.promise
exports.logDiaper = logDiaper

# params: child, time, title, body
logMood = (params) =>
  formData = {
    Kid: params.child.id,
    C: 600,
    uts: params.time.format('HHmm'),
    ptm: params.time.format('HHmm'),
    pdt: params.time.format('YYMMDD'),
    n: params.body,
    txt: params.title,
    fmt: 'long',
    listKid: -1
  }
  logStatus(formData)

# params: child, time, title, body
logDiary = (params) =>
  formData = {
    Kid: params.child.id,
    C: 2600,
    uts: params.time.format('HHmm'),
    ptm: params.time.format('HHmm'),
    pdt: params.time.format('YYMMDD'),
    n: params.body,
    txt: params.title,
    fmt: 'long',
    listKid: -1
  }
  logStatus(formData)

# params: childID, time, txt, endTime (optional)
logActivity = (params) =>
  formData = {
    Kid: params.child.id,
    C: 700,
    fmt: 'long'
    txt: params.text || params.body,
    n: params.body,
    listKid: -1
  }
  if params.time
    formData.uts = params.time.format('HHmm')
    formData.ptm = params.time.format('HHmm')
    formData.pdt = params.time.format('YYMMDD')
  if params.endTime
    formData.d = params.endTime.diff(params.time, 'minutes')
    formData.e = params.endTime.format('M/DD/YYYY HH:mm')
    formData.ptm = params.endTime.format('HHmm')
  logStatus(formData)
exports.logActivity = logActivity

  # params: childID, weight (oz), text, body (optional)
logWeight = (params) =>
  formData = {
    Kid: params.child.id,
    C: 1700,
    fmt: 'long'
    uts: params.time.format('HHmm')
    ptm: params.time.format('HHmm')
    pdt: params.time.format('YYMMDD')
    txt: params.text || params.body,
    p: params.weight,
    n: params.body,
    listKid: -1
  }
  db = new sqlite3.Database(DB_FILE)
  p = q.defer()
  db.run('INSERT INTO data (startTime, endTime, activity, quantity, label, notes) VALUES (?, ?, ?, ?, ?, ?)',
    [params.time.toDate(), params.endTime.toDate(), 'Weight', params.weight, params.text || params.body, params.body], () =>
      db.close()
      p.resolve(logStatus(formData))
  )
  p.promise
exports.logWeight = logWeight

# params: childID, time, endTime (optional)
logSleep = (params) =>
  p = q.defer()
  label = params.text
  formData = {
    Kid: params.child.id,
    C: 501,
    fmt: 'long'
    p: '0,0,,', # options
    listKid: -1
  }
  if params.endTime
    if !params.time  # woke up
      # retrieve it from summary.dtOfLastSleeping
      getBabyConnectSummary({child: params.child, time: params.endTime}).then((data) =>
        params.time = moment(data.summary.timeOfLastSleeping, 'M/DD/YYYY HH:mm')
        p.resolve(formData)
      )
    formData.C = 500
    formData.isst = 1
  else
    p.resolve(formData)
  p.promise.then((formData) =>
    if params.time
      formData.uts = params.time.format('HHmm')
      formData.ptm = params.time.format('HHmm')
      formData.pdt = params.time.format('YYMMDD')
      label ||= (if params.child then params.child.name + ' ' else '') + ' starts sleeping'
      params.activity = 'Sleep Start'
    if params.endTime
      formData.d = params.endTime.diff(params.time, 'minutes')
      formData.e = params.endTime.format('M/DD/YYYY HH:mm')
      formData.ptm = params.endTime.format('HHmm')
      label ||= (if params.child then params.child.name + ' ' else '') + 'stops sleeping (' + formData.d + 'min)'
      params.activity = 'Sleep'
    formData.txt = label
    db = new sqlite3.Database(DB_FILE)
    p2 = q.defer()
    db.run('INSERT INTO data (startTime, endTime, activity, duration, label, notes) VALUES (?, ?, ?, ?, ?, ?)',
      [params.time.toDate(),
       if params.endTime then params.endTime.toDate() else null,
       params.activity,
       formData.d || 0,
       formData.txt || '', params.body], () =>
        db.close()
        p2.resolve(logStatus(formData))
    )
    p2.promise
  )
exports.logSleep = logSleep
  
logQuantifiedMeasurement = (params) =>
  categoryID = config.quantified.measurements[params.category] || params.category || params.categoryID
  url = 'http://quantifiedawesome.com/measurement_logs.json?auth_token=' + config.quantified.token + '&measurement_id=' + categoryID
  form = {measurement_log: {value: params.value, measurement_id: categoryID, datetime: params.time, notes: params.notes}}
  return rp({
    jar: true, followRedirect: true, followAllRedirects: true,
    url: url,
    form: form,
    method: 'POST',
  })

# data should be a fast-csv object
cacheData = (data) =>
  rows = []
  minTime = null
  maxTime = null
  exists = fs.existsSync(DB_FILE)
  db = new sqlite3.Database(DB_FILE)
  if !exists
    db.run('CREATE TABLE data (startTime DATETIME, endTime DATETIME, activity VARCHAR(255), duration INTEGER, Quantity VARCHAR(255), extra TEXT, label TEXT, Notes TEXT,Caregiver VARCHAR(255),ChildName VARCHAR(255))')
  data.on('data', (row) =>
    row.startTime = moment(row['Start Time'], 'YYYY-MM-D HH:mm').toDate()
    row.endTime = moment(row['End Time'], 'YYYY-MM-D HH:mm').toDate()
    # Delete overlapping records
    if !minTime || row.startTime < minTime then minTime = row.startTime
    if !maxTime || row.endTime > maxTime then maxTime = row.endTime
    rows.push row
  ).on('end', () =>
    stmt = db.prepare("INSERT INTO data (startTime, endTime, activity, duration, quantity, extra, label, notes, caregiver, childname) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)");
    db.run('BEGIN TRANSACTION')
    db.run('DELETE FROM data WHERE startTime >= ? AND endTime <= ?', [minTime, maxTime], (err) =>
      promises = []
      for row in rows
        p = q.defer()
        promises.push p.promise
        stmt.run([row.startTime, row.endTime, row['Activity'], row['Duration (min)'], row['Quantity'], row['Extra data'], row['Text'], row['Notes'], row['Caregiver'], row['Child Name']], (err) =>
          p.resolve(err)
        )
      q.allSettled(promises).then(
        db.run('COMMIT')
        stmt.finalize()
        db.close()
        console.log 'Updated ', minTime, ' to ', maxTime
      )
    )
  )
exports.cacheData = cacheData

cacheDataFromFile = () =>
  # Open data.csv
  data = csv.fromPath DATA_FILE, {headers: true}
  q(cacheData(data))

getLogs = (params) =>
  # Open SQLite database
  db = new sqlite3.Database(DB_FILE)
  p = q.defer()
  threshold = null
  query = 'SELECT time, text, parsed FROM logs WHERE 1=1'
  queryParams = {}
  if params.days
    query += ' AND time >= $date'
    queryParams.$date = moment().subtract(+params.days, 'days').toDate()
  if params.start
    query += ' AND time >= $start'
    queryParams.$start = moment(params.start).toDate()
  if params.end
    query += ' AND time <= $end'
    queryParams.$end = moment(params.end).toDate()
  query += ' ORDER BY time DESC'
  db.all(query, queryParams, (err, records) =>
    if err
      console.log err
    csv.writeToString(records, {headers: true}, (err, data) =>
      p.resolve(data)
    )
  )
  p.promise
exports.getLogs = getLogs

  
# params: activity
convertToCSV = (params) =>
  # Open SQLite database
  db = new sqlite3.Database(DB_FILE)
  p = q.defer()
  threshold = null
  query = 'SELECT startTime, endTime, activity, duration, quantity, extra, label, notes, caregiver, childname FROM data WHERE 1=1'
  queryParams = {}
  if params.activity
    query += ' AND activity = $activity'
    queryParams.$activity = params.activity
  if params.days
    query += ' AND startTime >= $date'
    queryParams.$date = moment().subtract(+params.days, 'days').toDate()
  if params.start
    query += ' AND endTime >= $start'
    queryParams.$start = moment(params.start).toDate()
  if params.end
    query += ' AND startTime <= $end'
    queryParams.$end = moment(params.end).toDate()
  query += ' ORDER BY startTime DESC'
  db.all(query, queryParams, (err, records) =>
    if err
      console.log err
    csv.writeToString(records, {headers: true, transform: (row) =>
      return {
        'Start Time': moment(row.startTime).format('YYYY-MM-D HH:mm'),
        'End Time': moment(row.endTime).format('YYYY-MM-D HH:mm'),
        'Activity': row.activity,
        'Duration (min)': row.duration,
        'Quantity': row.Quantity,
        'Extra data': row.extra,
        'Text': row.label,
        'Notes': row.Notes,
        'Caregiver': row.Caregiver,
        'Child Name': row.ChildName
      }
    }, (err, data) =>
      p.resolve(data)
    )
  )
  p.promise
exports.convertToCSV = convertToCSV

# params: date, child
refreshMonth = (params) =>
  retrieveMonth(params).then (y) =>
    fs.writeFile(DATA_FILE, y)

update = (params) ->
  if params.span == 'week'
    retrieveFunction = retrieveWeek
  else if params.span == 'day' || params.span == 'date'
    retrieveFunction = retrieveDay
  else
    retrieveFunction = retrieveMonth
  retrieveFunction(params).then((body) =>
    cacheData(csv.fromString(body, {headers: true}))
  )
exports.update = update

getRelativeTime = (s, base) ->
  if !base
    base = moment()
  else
    base = base.clone()
  if matches = s.match(/([0-9]+):([0-9]+)/)
    base.hour(matches[1])
    base.minute(matches[2])
  if matches = s.match(/([0-9]+)-([0-9]+)-([0-9]+)/)
    base.year(+matches[1])
    base.month(+matches[2] - 1)
    base.date(+matches[3])
  else if matches = s.match(/([0-9]+)-([0-9]+)/)
    base.month(+matches[1] - 1)
    base.date(matches[2])
  if s.match /last week/
    base.subtract(1, 'week').endOf('week')
  if s.match /last month/
    base.subtract(1, 'month').startOf('month')
  if s.match /yesterday/
    base.subtract(1, 'day')
  if matches = s.match /([0-9]+) weeks? ago/
    base.subtract(+matches[1], 'week').endOf('week')
  if matches = s.match /([0-9]+) months? ago/
    base.subtract(+matches[1], 'month').startOf('month')
  if matches = s.match /([0-9]+) minutes? ago/
    base.subtract(+matches[1], 'minute')
  if matches = s.match /([0-9]+) hours? ago/
    base.subtract(+matches[1], 'hour')
  if matches = s.match(/([0-9]+)d/)
    base.subtract(+matches[1], 'days')
  if matches = s.match(/([0-9]+)m/)
    base.subtract(+matches[1], 'minutes')
  if matches = s.match(/([0-9]+)h/)
    base.subtract(+matches[1], 'hours')
  base
exports.getRelativeTime = getRelativeTime

# params: user, name, value (time, ...)
saveNote = (params) ->
  db = new sqlite3.Database(DB_FILE)
  p = q.defer()
  db.run('INSERT OR REPLACE INTO tempdata (user, name, value, time) VALUES (?, ?, ?, ?)', [params.user, params.name, JSON.stringify(params.value), params.time.toDate()], (err) =>
    p.resolve(err)
  )
  p.promise
exports.saveNote = saveNote

# params: user, name
loadNote = (params) ->
  db = new sqlite3.Database(DB_FILE)
  p = q.defer()
  db.get('SELECT value, time FROM tempdata WHERE user=? AND name=?', [params.user, params.name], (err, row) =>
    if row
      p.resolve({value: JSON.parse(row.value), time: row.time})
    else
      p.resolve({})
  )
  p.promise
exports.loadNote = loadNote

# params: user, name
clearNote = (params) ->
  db = new sqlite3.Database(DB_FILE)
  p = q.defer()
  db.run('DELETE FROM tempdata WHERE user=? AND name=?', [params.user, params.name], (err) =>
    p.resolve(err)
  )
  p.promise
exports.clearNote = clearNote

parseCommand = (s, params) ->
  matches = null
  # Try to parse the time
  params.startTime = getRelativeTime(s, moment())
  params.time = params.startTime
  if matches = s.match(/note (.+)/)
    params.body = matches[1]
  if matches = s.match /(for|over) ([0-9]+) minutes/
    _.assign(params, {duration: +matches[2]})
  if matches = s.match /(to|until) ([0-9:]+)/
    params.endTime = getRelativeTime(matches[2], moment())
    params.duration = params.endTime.diff(params.startTime, 'minutes')
  # Try to parse duration or end time
  # Other commands
  if s.match /cache file/
    _.assign(params, {function: cacheDataFromFile, command: 'cache'})
  else if s.match /save/
    if matches = s.match /save ({.*)/
      _.assign(params, {value: JSON.parse(matches[1]), command: 'save'})
    else if matches = s.match /save (.*)/
      _.assign(params, {value: {body: matches[1]}})
    _.assign(params, {function: saveNote, name: 'note', command: 'save'})
  else if s.match /load/
    _.assign(params, {function: loadNote, name: 'note', command: 'load'})
  else if s.match /clear/
    _.assign(params, {function: clearNote, name: 'note', command: 'clear'})
  else if s.match(/wet diaper/)
    _.assign(params, {function: logDiaper, type: 'wet', command: 'diaper'})
    if s.match (/open air/)
      params.openAir = true
  else if s.match(/BM diaper/)
    _.assign(params, {function: logDiaper, type: 'BM', command: 'diaper'})
    if s.match (/open air/)
      params.openAir = true
  else if s.match /potty/
    _.assign(params, {function: logPotty, command: 'potty'})
  else if matches = s.match /\b(ate|refused) (.*)/
    _.assign(params, {function: logSolids, body: matches[0] + (if params.body then ' ' + params.body else ''), command: 'eat'})
  else if s.match /sleep/
    _.assign(params, {function: logSleep, command: 'sleep'})
  else if s.match /wake/
    _.assign(params, {function: logSleep, endTime: params.time, startTime: null, time: null, command: 'wake'})
  else if s.match /update/
    _.assign(params, {function: update, command: 'update'})
    if s.match /month/
      _.assign(params, {span: 'month'})
    else if s.match /day|yesterday|today/
      _.assign(params, {span: 'day'})
    else
      _.assign(params, {span: 'week'})
  else if s.match /weighed/
    weight = 0
    if matches = s.match(/([\.0-9]+) kg/)
      weight = +matches[1] * 2.2 * 16
    else if matches = s.match(/([\.0-9]+) ?lbs?( ([\.0-9]+) ?oz)?/)
      weight = +matches[1] * 16 + (+matches[3] || 0)
    _.assign(params, {function: logWeight, weight: weight, text: s, command: 'weight'})
  else if s.match /drank/
    params.function = logSupplement
    params.command = 'drank'
    if matches = s.match(/([.0-9]+) oz/)
      params.quantity = +matches[1]
    if s.match /formula/i
      params.type = 'Formula'
    if s.match /milk/i
      params.type = 'Milk'
  else if matches = s.match /mood (is|was) (.*)/
    _.assign(params, {
      function: logMood,
      title: (if params.child then (params.child.name + ' is ') else '') + matches[2],
      command: 'mood'
    })
  else if matches = s.match /(crying|calm|cried|cooing|cooed|smiling|calm|smiled)/
    _.assign(params, {
      function: logMood,
      title: (if params.child then (params.child.name + ' - ') else '') + matches[1]
      command: 'mood'
    })
  else if s.match /nursed?/
    params.function = logNurse
    params.command = 'nursed'
    myRegexp = /(left|right) (side )?for ([0-9]+) minutes?/g
    while (matches = myRegexp.exec(s)) != null
      params[matches[1]] = +matches[3]
    myRegexp = /(left|right) (side )?from ([0-9:]+) to ([0-9:]+)/g
    timeSpecified = false
    while (matches = myRegexp.exec(s)) != null
      tempStart = getRelativeTime(matches[3])
      tempEnd = getRelativeTime(matches[4])
      params[matches[1]] = tempEnd.diff(tempStart, 'minutes')
      params.startTime = tempStart
      params.endTime = tempEnd
      timeSpecified = true
    if !params.left and !params.right
      params.left = params.right = params.duration / 2
      params.lastSide = 'right'
    if s.match /left.*right/
      params.lastSide = 'right'
    else if s.match /right.*left/
      params.lastSide = 'left'
    else if s.match /left/
      params.lastSide = 'left'
    else if s.match /right/
      params.lastSide = 'right'
    if s.match /starting/
      params.endTime = params.startTime.clone().add((params.left || 0 + params.right || 0), 'minutes')
    else if !timeSpecified
      params.endTime = params.startTime.clone()
      params.startTime.subtract((params.left || 0 + params.right || 0), 'minutes')
      params.time = params.startTime
  else if s.match /summary/
    params.command = 'summary'
    params.function = getBabyConnectSummary
  else if matches = s.match(/activity/)
    _.assign(params, {function: logActivity, command: 'activity'})
  if params.duration and !params.endTime
    params.endTime = params.startTime.clone().add(params.duration, 'minutes')
  if params.endTime and !params.duration
    params.duration = params.endTime.diff(params.startTime, 'minutes')
  params
exports.parseCommand = parseCommand

executeCommand = (s, params) =>
  p = parseCommand(s, params)
  return p.function(p)
exports.executeCommand = executeCommand

if require.main == module
  p = {child: config.babyConnect.kids.main}
  executeCommand(process.argv[2], p).then (result) =>
    console.log result
  .catch (err) =>
    console.log err
