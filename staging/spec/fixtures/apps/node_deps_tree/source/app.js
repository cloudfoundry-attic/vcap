var colors = require("colors");
var express = require("express");
var app = express();
var port = process.env.VCAP_APP_PORT || 3000;

app.get("/", function(req, res){
  res.send("Hello from express");
});

app.listen(port);