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
#   asgard url <url> - Get/set the asgard base url
#

asgardUrl = process.env.HUBOT_ASGARD_URL or 'http://127.0.0.1'
region = process.env.HUBOT_ASGARD_REGION or 'us-east-1'

eco = require "eco"
fs  = require "fs"

getBaseUrl = ->
  separator = if (asgardUrl.slice(-1)) == '/' then '' else '/'
  return asgardUrl + separator + region + '/'

getAsgardName = (name) ->
  asgardName = switch
    when name == 'ami' || name == 'a' then 'image'
    wjem name == 'app' then 'application'
    when name == 'autoscaling' || name == 'as' then 'autoScaling'
    when name == 'loadbalancer' || name == 'lb' then 'loadBalancer'
    when name == 'i' then 'instance'
    when name == 'c' then 'cluster'
    else name

  return asgardName

getTemplate = (templateItem) ->
  path = "/../templates/asgard-#{templateItem}.eco"
  return fs.readFileSync __dirname + path, "utf-8"

asgardGet = (msg, path, templateItem) ->
  msg.http(getBaseUrl() + path)
    .get() (err, res, body) ->
      data = JSON.parse(body)
      msg.send response data, getTemplate templateItem

response = (dataIn, template) ->
  return eco.render template, data: dataIn

module.exports = (robot) ->
  robot.hear /^(asgard|a) (ami|a|instance|i|application|app)$/, (msg) ->
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
