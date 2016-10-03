# Description:
#   Asgard provides hubot commands for interfacing with a NetflixOSS
#   Asgard instance via API.
#
# Dependencies:
#   eco (>= 1.1.0)
#
# Configuration:
#   process.env.HUBOT_ASGARD_URL or http://127.0.0.1/
#   process.env.HUBOT_ASGARD_REGION or us-east-1
#
# Commands:
#   asgard ami - List AMIs per region (careful if public enabled)
#   asgard ami <id> - Show details for ami ID (ami-[a-f0-9]{8})
#   asgard application - List applications per region
#   asgard autoscaling <name> - Show details for autoscaling group <name>
#   asgard autoscaling <name> <minSize> <maxSize - Change the min/max size for an ASG
#   asgard autoscaling (activate|deactive|delete) <name> - Enable, disable or delete an ASG
#   asgard cluster - List clusters per region
#   asgard cluster <name> - Show details for cluster <name>
#   asgard instance - List instances per region
#   asgard instance <app> - List instances per <app> per region
#   asgard instance <id> - Show details for instance <id> (i-[a-f0-9]{8})
#   asgard loadbalancer - List loadbalancers per region
#   asgard region <region> - Get/set the asgard region
#   asgard rollingpush <asg> <ami> - Start a rolling push of <ami> into <asg>
#   asgard next <cluster> <ami> <true|false> - Create the next autoscaling group using <ami> with trafficEnabled true|false.
#   asgard task <id> - Show details for a given task
#   asgard url <url> - Get/set the asgard base url
#
#

asgardUrl = process.env.HUBOT_ASGARD_URL or 'http://127.0.0.1'
region = process.env.HUBOT_ASGARD_REGION or 'us-east-1'
debug = process.env.HUBOT_ASGARD_DEBUG or false

async = require "async"
eco = require "eco"
fs  = require "fs"

log = (event) ->
  if debug
    console.log event

getBaseUrl = ->
  return asgardUrl + region + '/'

getAsgardName = (name) ->
  asgardName = switch
    when name == 'ami' || name == 'a' then 'image'
    when name == 'app' then 'application'
    when name == 'autoscaling' || name == 'as' then 'autoScaling'
    when name == 'loadbalancer' || name == 'lb' then 'loadBalancer'
    when name == 'i' then 'instance'
    when name == 'c' then 'cluster'
    when name == 't' then 'task'
    else name

  return asgardName

getTemplate = (templateItem) ->
  path = "/../templates/asgard-#{templateItem}.eco"
  return fs.readFileSync __dirname + path, "utf-8"

asgardGetData = (msg, path, callback) ->
  msg.http(getBaseUrl() + path)
    .get() (err, res, body) ->
      log body
      callback null, JSON.parse(body)

asgardPostData = (msg, path, params, callback) ->
  log 'curl -d "'+params+'" '+getBaseUrl() + path
  msg.http(getBaseUrl() + path)
    .headers("Accept": "*/*", "Content-Type": "application/x-www-form-urlencoded", "Content-Length": params.length)
    .post(params) (err, res, body) ->
      log res
      callback null, res

asgardGet = (msg, path, templateItem) ->
  msg.http(getBaseUrl() + path)
    .get() (err, res, body) ->
      log JSON.parse(body)
      msg.send response JSON.parse(body), getTemplate templateItem

asgardCreateTaskMsg = (msg, location, callback) ->
  taskId = location.substr(location.lastIndexOf("/")+1)
  msg.send "'asgard task #{taskId}' or " + getBaseUrl() + "task/show/#{taskId}"
  callback null, null

response = (dataIn, template) ->
  return eco.render template, data: dataIn

module.exports = (robot) ->
  robot.hear /^(asgard|a) (ami|a|instance|i|application|app|task|t)$/, (msg) ->
    item = getAsgardName msg.match[2]
    asgardGet msg, item + '/list.json', item

  robot.hear /^(asgard|a) (autoscaling|as|cluster|c|loadbalancer|lb)( ([\w\d-]+))?$/, (msg) ->
    path = tpl = getAsgardName msg.match[2]
    path += if msg.match[4] then "/show/#{msg.match[4]}.json" else '/list.json'
    asgardGet msg, path, tpl

  robot.hear /^(asgard|a) region( ([\w-]+))?$/, (msg) ->
    if msg.match[3]
      region = msg.match[3]
      robot.brain.set 'asgardRegion', region

    msg.send "Region is #{region}."

  # Ami
  robot.hear /^(asgard|a) (ami|a) (ami-[a-f0-9]{8})$/, (msg) ->
    item = getAsgardName msg.match[2]
    path = item + "/show/#msg.match[3]}.json"
    asgardGet msg, path, item

  # Instance APP (Eureka dependent)
  robot.hear /^(asgard|a) (instance|i) ([a-zA-Z0-9]+)$/, (msg) ->
    item = getAsgardName msg.match[2]
    path = item + "/list/#{msg.match[3]}.json"
    asgardGet msg, path, item

  # Instance ID
  robot.hear /^(asgard|a) (instance|i) (i-[a-f0-9]{8})$/, (msg) ->
    item = getAsgardName msg.match[2]
    path = item + "/show/#{msg.match[3]}.json"
    asgardGet msg, path, item

  # Task ID
  robot.hear /^(asgard|a) (task|t) ([\d]+)$/, (msg) ->
    item = getAsgardName msg.match[2]
    path = item + "/show/#{msg.match[3]}.json"
    asgardGet msg, path, item

  # Autoscaling group min-max update
  robot.hear /^(asgard|a) (autoscaling|as) ([\w\d-]+) ([\d]+) ([\d]+)$/, (msg) ->
    path = 'cluster/resize'
    params = "name=#{msg.match[3]}&minSize=#{msg.match[4]}&maxSize=#{msg.match[5]}"
    asgardPostData msg, path, params, (err, data) ->
      if data.statusCode == 302
        asgardCreateTaskMsg msg, data.headers.location, (err, data) ->
          if err
            log err

      else
        msg.send "Oops: #{err}"

  robot.hear /^(asgard|a) url( (.*))?$/, (msg) ->
    if msg.match[3]
      asgardUrl = if (msg.match[3].slice(-1)) == '/' then msg.match[3] else "#{msg.match[3]}/"
      robot.brain.set 'asgardUrl', asgardUrl

    msg.send "URL is #{asgardUrl}."

  robot.hear /^(asgard|a) (rollingpush|rp) ([\w\d-]+) (ami-[a-f0-9]{8})$/, (msg) ->
    asg = msg.match[3]
    ami = msg.match[4]
    path = "autoScaling/show/#{asg}.json"
    async.waterfall [
      (callback) ->
        asgardGetData msg, path, callback
      (data, callback) ->
        sg = "selectedSecurityGroups=" + data.launchConfiguration.securityGroups.join("&selectedSecurityGroups=")
        params = "name=#{asg}&appName=#{data.app.name}&imageId=#{ami}&instanceType=#{data.launchConfiguration.instanceType}&keyName=#{data.launchConfiguration.keyName}&#{sg}&relaunchCount=#{data.group.desiredCapacity}&concurrentRelaunches=1&newestFirst=false&checkHealth=on&afterBootWait=30"
        path = "push/startRolling"
        asgardPostData msg, path, params, callback
      (data, callback) ->
        if data.statusCode == 302
          asgardCreateTaskMsg msg, data.headers.location, callback
        else
          callback "Unexpected result data: #{data}", null

    ], (err, result) ->
      if err
        console.log err

  robot.hear /^(asgard|a) (next) ([\w\d-]+) (ami-[a-f0-9]{8})( (true|false))?$/, (msg) ->
    cluster = msg.match[3]
    ami = msg.match[4]
    traffic = if (msg.match[6] && msg.match[6] == true) then "&trafficAllowed=true" else ''
    params = "name=#{cluster}&imageId=#{ami}&checkHealth=true#{traffic}"
    path = "cluster/createNextGroup"
    async.waterfall [
      (callback) ->
        asgardPostData msg, path, params, callback
      (data, callback) ->
        if data.statusCode == 302
          asgardCreateTaskMsg msg, data.headers.location, callback
        else
          callback "Unexpected result statusCode: #{data}", null

    ], (err, result) ->
      if err
        console.log err

  robot.hear /^(asgard|a) (autoscaling|as) (activate|deactivate|delete) ([\w\d-]+)$/, (msg) ->
    asg = msg.match[4]
    params = "name=#{asg}"
    path = "cluster/#{msg.match[3]}"
    async.waterfall [
      (callback) ->
        asgardPostData msg, path, params, callback
      (data, callback) ->
        if data.statusCode == 302
          asgardCreateTaskMsg msg, data.headers.location, callback
        else
          callback "Unexpected result statusCode: #{data}", null

    ], (err, result) ->
      if err
        console.log err
