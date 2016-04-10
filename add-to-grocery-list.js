#!/usr/bin/env node

/*
  Adds the grocery items specified as command-line arguments.
  Todo: Read from stdin if no arguments are specified.
 */
  
var config = require(require('home-dir')() + '/.secret');
var rp = require('request-promise');
var cheerio = require('cheerio');
var split = require('split');

function login() {
  return rp({url: 'https://www.ourgroceries.com/sign-in?url=' + encodeURIComponent('/your-lists/list/' + config.grocery.list),
             jar: true,
             method: 'POST',
             followRedirect: true,
             followAllRedirects: true,
             form: {emailAddress: config.grocery.email, password: config.grocery.password}
            });
}

function addGroceries(items) {
  var formData = {command: 'importItems',
                  listId: config.grocery.list,
                  importFile: '',
                  items: items.join("\n")};
  var req = rp({url: 'https://www.ourgroceries.com/your-lists/',
                jar: true,
                method: 'POST',
                followRedirect: true,
                followAllRedirects: true,
                formData: formData});
  return req;
}

var items = [];
if (process.argv.length < 3) {
  // No arguments specified - read from stdin
  process.stdin.pipe(split()).on('data', function(line) {
    if (line) { items.push(line); }
  }).on('end', function() {
    login().then(function() { addGroceries(items); }).then(function(a) { console.log('Added.'); });
  });
} else {
  items = process.argv.slice(2);
  login().then(function() { addGroceries(items); }).then(function(a) { console.log('Added.'); });
}

