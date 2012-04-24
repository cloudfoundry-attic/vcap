var app = require('express').createServer();

app.get('/', function(req, res){
    res.send('hello world test using express and npm. My address:' + app.address().address + ", my port: " + app.address().port);
});

var port = process.env.VCAP_APP_PORT || 3000
app.listen(port);

console.log(app.address());
console.log('Express server started on port %s', app.address().port);