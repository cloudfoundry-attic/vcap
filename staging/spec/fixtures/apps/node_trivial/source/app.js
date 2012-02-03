var http = require('http');
var url = require('url');

HOST = null;

var host = process.env.VCAP_APP_HOST || 'localhost';
var port = process.env.VCAP_APP_PORT || 3000

http.createServer(function (req, res) {
  res.writeHead(200, {'Content-Type': 'text/html'});
  res.write('<h1>Hello from the Cloud! ');
  res.write('via: ' + host + ':' + port);
  res.end('</h1>');
}).listen(port, null);

console.log('Server running at http://' + host + ':' + port + '/');
