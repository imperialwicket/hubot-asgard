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
#   asgard autoscaling NAME - Show details for autoscaling group NAME
#   asgard cluster NAME - Show details for cluster NAME
#   asgard instance - List instances per region
#   asgard instance APP - List instances per app per region
#   asgard instance ID - Show details for instance ID (i-[a-f0-9])
#   asgard loadbalancer - List loadbalancers per region
#   asgard region [REGION] - Get/set the asgard region
#   asgard url [URL] - Get/set the asgard base url
#

asgardUrl = process.env.HUBOT_ASGARD_URL or 'http://127.0.0.1'
region = process.env.HUBOT_ASGARD_REGION or 'us-east-1'

eco = require "eco"
fs  = require "fs"

getBaseUrl = ->
  separator = if (asgardUrl.slice(-1)) == '/' then '' else '/'
  return asgardUrl + separator + region + '/'

getAsgardName = (botName) ->
  asgardName = switch
    when botName == 'ami' then 'image'
    when botName == 'autoscaling' then 'autoScaling'
    when botName == 'loadbalancer' then 'loadBalancer'
    else botName

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
  robot.hear /^asgard (ami|instance|loadbalancer)/, (msg) ->
    item = getAsgardName msg.match[1]
    asgardGet msg, item + '/list.json', item

  robot.hear /^asgard (autoscaling|cluster)( ([\w\d-]+))?$/, (msg) ->
    path = tpl = getAsgardName msg.match[1]
    path += if msg.match[2] then "/show/#msg.match[3]}.json" else '/list.json'
    asgardGet msg, path, tpl

    tpl = 'cluster'
    path += if (msg.match[2]) then "show/#{msg.match[2]}.json" else 'list.json'
    asgardGet msg, path, tpl

  robot.hear /^asgard region( ([\w-]+))?$/, (msg) ->
    if msg.match[2]
      region = msg.match[2]
      robot.brain.set 'asgardRegion', region

    msg.send "Region is #{region}."

  # Ami
  robot.hear /^asgard ami (ami-[a-f0-9]{8})$/, (msg) ->
    item = getAsgardName msg.match[1]
    path = item + "/show/#msg.match[1]}.json"
    asgardGet msg, path, item

  # Instace APP
  robot.hear /^asgard instance ([a-zA-Z0-9]+)$/, (msg) ->
    path = "instance/list/#{msg.match[1]}.json"
    asgardGet msg, path, 'instance'

  # Instance ID
  robot.hear /^asgard instance (i-[a-f0-9]{8})$/, (msg) ->
    path = "instance/show/#{msg.match[1]}.json"
    asgardGet msg, path, 'instance'

  robot.hear /^asgard url( (.*))?$/, (msg) ->
    if msg.match[2]
      asgardUrl = msg.match[2]
      robot.brain.set 'asgardUrl', asgardUrl

    msg.send "URL is #{asgardUrl}."
