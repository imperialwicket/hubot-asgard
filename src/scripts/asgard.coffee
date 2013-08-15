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
#   asgard cluster <name> - Show details for cluster <name>
#   asgard instance - List instances per region
#   asgard instance <app> - List instances per <app> per region
#   asgard instance <id> - Show details for instance <id> (i-[a-f0-9]{8})
#   asgard loadbalancer - List loadbalancers per region
#   asgard region <region> - Get/set the asgard region
#   asgard rollingpush <asg> <ami> - Start a rolling push of <ami> into <asg>
#   asgard url <url> - Get/set the asgard base url
#
#

asgardUrl = process.env.HUBOT_ASGARD_URL or 'http://127.0.0.1'
region = process.env.HUBOT_ASGARD_REGION or 'us-east-1'

async = require "async"
eco = require "eco"
fs  = require "fs"

getBaseUrl = ->
  separator = if (asgardUrl.slice(-1)) == '/' then '' else '/'
  return asgardUrl + separator + region + '/'

getAsgardName = (name) ->
  asgardName = switch
    when name == 'ami' || name == 'a' then 'image'
    when name == 'app' then 'application'
    when name == 'autoscaling' || name == 'as' then 'autoScaling'
    when name == 'loadbalancer' || name == 'lb' then 'loadBalancer'
    when name == 'i' then 'instance'
    when name == 'c' then 'cluster'
    else name

  return asgardName

getTemplate = (templateItem) ->
  path = "/../templates/asgard-#{templateItem}.eco"
  return fs.readFileSync __dirname + path, "utf-8"

asgardGetData = (msg, path, callback) ->
  msg.http(getBaseUrl() + path)
    .get() (err, res, body) ->
      callback null, JSON.parse(body)

asgardPostData = (msg, path, params, callback) ->
  console.log 'curl -d "'+params+'" '+getBaseUrl() + path
  msg.http(getBaseUrl() + path)
    .headers("Accept:": "*/*", "Content-Type": "application/x-www-form-urlencoded", "Content-Length": params.length)
    .post(params) (err, res, body) ->
      console.log res
      callback null, res 

asgardGet = (msg, path, templateItem) ->
  msg.http(getBaseUrl() + path)
    .get() (err, res, body) ->
      msg.send response JSON.parse(body), getTemplate templateItem

response = (dataIn, template) ->
  return eco.render template, data: dataIn

module.exports = (robot) ->
  robot.hear /^(asgard|a) (ami|a|instance|i|application|app)$/, (msg) ->
    item = getAsgardName msg.match[2]
    asgardGet msg, item + '/list.json', item

  robot.hear /^(asgard|a) (autoscaling|as|cluster|c|loadbalancer|lb|task|t)( ([\w\d-]+))?$/, (msg) ->
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

  # Instace APP (Eureka dependent)
  robot.hear /^(asgard|a) (instance|i) ([a-zA-Z0-9]+)$/, (msg) ->
    item = getAsgardName msg.match[3]
    path = item + "/list/#{msg.match[3]}.json"
    asgardGet msg, path, item

  # Instance ID
  robot.hear /^(asgard|a) (instance|i) (i-[a-f0-9]{8})$/, (msg) ->
    item = getAsgardName msg.match[3]
    path = item + "/show/#{msg.match[3]}.json"
    asgardGet msg, path, item

  robot.hear /^(asgard|a) url( (.*))?$/, (msg) ->
    if msg.match[3]
      asgardUrl = msg.match[3]
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
      (result, callback) ->
        if result.statusCode == 302
          location = result.headers.location
          taskId = location.substr location.lastIndexOf "/"

        return taskId
    ], (err, result) ->
      if err
        console.error err
      else
        msg.send getBaseUrl()+"task/show/#{result} or 'asgard task 15'"

