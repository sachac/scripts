// ==UserScript==
// @name         VideoHighlight
// @namespace    http://sachachua.com
// @version      0.1
// @description  Check status against hard-coded libraries
// @author       Sacha Chua
// @match        http://www.torontopubliclibrary.ca/detail.jsp*
// @require      https://cdnjs.cloudflare.com/ajax/libs/jquery/2.1.4/jquery.min.js
// @require      https://cdnjs.cloudflare.com/ajax/libs/moment.js/2.10.6/moment.min.js

// ==/UserScript==
/* jshint -W097 */
'use strict';

var branches = {
    "Annette Street": "M 10-8:30 T 12:30-8:30 W 10-6 Th 12:30-8:30 F 10-6 Sat 9-5",
    "Runnymede": "M 9-8:30 T 9-8:30 W 9-8:30 Th 9-8:30 F 9-5 Sat 9-5",
    "Perth/Dupont": "T 12:30-8:30 W 10-6 Th 12:30-8:30 F 10-6 Sat 9-5",
    "Jane/Dundas": "M 9-8:30 T 9-8:30 W 9-8:30 Th 9-8:30 F 9-5 Sat 9-5",
    "St. Clair/Silverthorn": "T 12:30-8:30 W 10-6 Th 12:30-8:30 F 10-6 Sat 9-5",
    "Swansea Memorial": "T 10-6 W 1-8 Th 10-6 Sat 10-5",
    "Bloor/Gladstone": "M 9-8:30 T 9-8:30 W 9-8:30 Th 9-8:30 F 9-5 Sat 9-5 Sun 1:30-5"
};

function parsePage(title, elem) {
  var matches;
  var results = [];
  var lastBranch = '';
  title = title.replace(/^[ \t\r\n]+|[ \t\r\n]+$/g, '');
  elem.find('tr.notranslate').each(function() {
    var row = $(this);
    var cells = row.find('td');
    var branch = $(cells[0]).text().replace(/^[ \t\r\n]+|[ \t\r\n]+$/g, '');
    var due = $(cells[2]).text().replace(/^[ \t\r\n]+|[ \t\r\n]+$/g, '');
    var status = $(cells[3]).text().replace(/^[ \t\r\n]+|[ \t\r\n]+$/g, '');
    if (branch) { lastBranch = branch; }
    else { branch = lastBranch; }
    if (branches[branch]) {
      if (status == 'On loan' && (matches = due.match(/Due: (.*)/))) {
        status = moment(matches[1], 'DD/MM/YYYY').format('YYYY-MM-DD');
      }
      if (status != 'Not Available - Search in Progress') {
        results.push([status, branch, title, branches[branch]]);
      }
    }
  });
  return results;
}

function displayInfo() {
  var data = parsePage($('#record-book-detail h1').text(), $('#item-availability'));
  var list = [];
  for (var i = 0; i < data.length; i++) {
    if (data[i][0] == 'In Library') {
      list.push('<span title="' + data[i][3] + '">' + data[i][1] + '</span>'); 
    }
  }
  if (list.length > 0) {
    $('#record-book-detail h1').after('<div style="font-weight: bold">' + list.join(', ') + '</div>');
  } else {
    $('#record-book-detail h1').after('<div style="font-weight: bold">Not yet available in your favourite libraries</div>');
  }
}

function waitForAvailability() {
  if ($('#item-availability').length == 0) {
    setTimeout(waitForAvailability, 500);
  } else {
    displayInfo();
  }
}

$(document).ready(waitForAvailability);
