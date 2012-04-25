;(function () {

  module.exports = versioner
  versioner.usage = "node versioner.js --package=pkg[@version] [--node-version=version] [--npm-version=version]"

  var parsePkg = new RegExp("^--package=(.*)$")
    , parseNodeV = new RegExp("^--node-version=(.*)$")
    , parseNpmV = new RegExp("^--npm-version=(.*)$")
    , nodev = process.version
    , pkg = null
    , npmv = null

  process.argv.forEach(function (arg) {
    if (opt = arg.match(parsePkg))
      pkg = opt[1]
    else if (opt = arg.match(parseNodeV))
      nodev = opt[1]
    else if (opt = arg.match(parseNpmV))
      npmv = opt[1]
  });

  if (pkg === null || pkg == "") failProcess("Usage: "+versioner.usage+"\n")

  var semver = require("semver")
    , http = require("http")
    , registryUrl = "registry.npmjs.org"

  versioner(pkg, nodev, npmv)

  function versioner (pkg, nodev, npmv) {
    var nv = pkg.split("@")
      , name = nv.shift()
      , version = nv.join("@") || ""

    registryGet(name, null, 10, function (data) {
      if (data && typeof data === "string") {
        try {
          data = JSON.parse(data)
        } catch (ex) {
          failProcess("Error parsing json from registry")
        }
      }
      else
        failProcess("Could not find requested package")

      var results = {}
        , versions = data.versions

      delete data.readme

      Object.keys(versions).forEach(function (v) {
        var eng = versions[v].engines

        if ((semver.satisfies(v, version)) &&
           (!eng || (!eng.node || semver.satisfies(nodev, eng.node) &&
           (!npmv || !eng.npm || semver.satisfies(npmv, eng.npm))))) {

          results[v] = versions[v].dist.tarball
        }
      })

      if (!Object.keys(results).length)
        failProcess("No compatible version found")

      var sorted = Object.keys(results).sort(semver.compare)
      var latestv = sorted.pop()
      var result = { "version" : latestv, "source" : results[latestv] }

      process.stdout.write(JSON.stringify(result))

    })
  }

  function registryGet (project, version, timeout, cb) {
    var uri = []
    uri.push(project || "")
    if (version) uri.push(version)
    uri = uri.join("/")

    var options = {
      host: registryUrl,
      method: "GET",
      port: 80,
      path: "/"+uri,
      headers: { "accept": "application/json" }
    }

    var request = http.request(options)
      , responded = false

    request.on("error", function (e) {
      failProcess("Error requesting registry: "+e)
    })

    if (typeof request.setTimeout !== "undefined") {
      // >= node 06
      request.setTimeout(timeout * 1000, function() {
        if (!responded)
          request.abort()
      })
    }
    else {
      // node 04
      process.nextTick(function() {
        if (typeof request.connection !== "undefined") {
          request.connection.setTimeout(timeout * 1000, function() {
            if (!responded) {
              request.abort()
              failProcess("Connection timeout to npm registry")
            }
          })
        }
      })
    }

    request.on("response", function (res) {
      responded = true
      if (res.statusCode == "200") {
        var body = ""
        res.on("data", function (chunk) {
          body += chunk
        })
        res.on("end", function () {
          cb(body)
        })
      }
      else
        failProcess("Unexpected response from registry: "+res.statusCode)
    })

    request.end()

  }

  function failProcess (err) {
    process.stdout.write(err)
    process.exit(1)
  }

})()
