#!/usr/bin/env node

/*
  Creates a prioritized list based on the flyers, like this:
  
Y	Clementines	2.47		2 lb bag product of Spain $2.47
Y	Smithfield Bacon	3.97		500 g selected varieties $3.97
Y	Thomas' Cinnamon Raisin Bread	2.50		675 g or Weston Kaisers 12's selected varieties $5.00 or $2.50 ea.
Y	Unico Tomatoes	0.97		796 mL or Beans 540 mL selected varieties $0.97
	Fresh Boneless Skinless Chicken Breast	3.33	2.78	BIG Pack!™ DECEMBER 18TH - 24TH ONLY! $3.33 lb/$7.34/kg save $2.78/lb
	Purex	3.97	2.02	2.03 L $3.97 save $2.02
	Frozen Steelhead Trout Fillets	5.97	2.00	filets de truite $5.97 lb/$13.16/kg save $2.00/lb
	Heinz Tomato Juice	0.97	1.52	1.36 L selected varieties $0.97 save $1.52
	Nestlé Multi-Pack Chocolate or Bagged Chocolate	2.88	0.61	45-246 g selected varieties $2.88 save 61¢
  ...
  */
  
var rp = require('request-promise');
var cheerio = require('cheerio');
var homeDir = require('home-dir');
var config = require(homeDir() + '/.secret');
var staples = config.grocery.staples; // array of lower-case text to match against flyer items
var flyerURL = config.grocery.flyerURL; // accessible URL

function parseValue(details) {
  var matches;
  var price;
  if ((matches = details.match(/\$([\.0-9]+)( |&nbsp;)+(ea|lb|\/kg)/i))) {
    price = matches[1];
  }
  else if ((matches = details.match(/\$([\.0-9]+)/i))) {
    price = matches[1];
  }
  else if ((matches = details.match(/([0-9]+) *¢/))) {
    price = parseInt(matches[1]) / 100.0;
  }
  return price;
}
                    
function getFlyer(url) {
  return rp.get(url).then(function(response) {
    var $ = cheerio.load(response);
    var results = [];
    $('table[colspan="2"]').each(function() {
      var cells = $(this).find('td');
      // $0.67  or  2/$3.00 or $1.25ea
      var item = $(cells[0]).text().replace(/^[ \t\r\n]+|[ \t\r\n]+$/g, '');
      var details = $(cells[1]).text().replace(/([ \t\r\n\u00a0\u0000]|&nbsp;)+/g, ' ').replace(/^[ \t\r\n]+|[ \t\r\n]+$/g, '');
      var matches;
      var save = '';
      var price = parseValue(details);
      details = details.replace(/ \/ [^A-Z$]+/, ' ');
      if (details.match(/To Our Valued Customers/)) {
        details = details.replace(/To Our Valued Customers.*/, 'DELAYED');
      }
      if ((matches = details.match(/save .*/))) {
        save = parseValue(matches[0]);
      }
      results.push({item: item,
                    details: details,
                    price: price,
                    save: save});
    });
    return results;
  });
}

function prioritizeFlyer(data) {
  for (var i = 0; i < data.length; i++) {
    var name = data[i].item.toLowerCase();
    for (var j = 0; j < staples.length; j++) {
      if (name.match(staples[j])) {
        data[i].priority = true;
      }
    }
  }
  return data.sort(function(a, b) {
    if (a.priority && !b.priority) return -1;
    if (!a.priority && b.priority) return 1;
    if (a.save > b.save) return -1;
    if (a.save < b.save) return 1;
    if (a.item < b.item) return -1;
    if (a.item > b.item) return 1;
  });
}

function displayFlyerData(data) {
  for (var i = 0; i < data.length; i++) {
    var o = data[i];
    console.log((o.priority ? 'Y' : '') + '\t' + o.item + "\t" + o.price + "\t" + o.save + "\t" + o.details);
  }
}

getFlyer(flyerURL).then(prioritizeFlyer).then(displayFlyerData);
