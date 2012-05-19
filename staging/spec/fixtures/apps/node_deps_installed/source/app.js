require("colors");

var port = process.env.VCAP_APP_PORT || 3000;

require("http").createServer(function (req, res) {
  res.writeHead(200, {"Content-Type" : "text/html"});
  res.end("Hello from Cloud!");
}).listen(port);