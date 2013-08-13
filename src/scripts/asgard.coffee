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

getTemplate = (templateItem) ->
  path = "/../templates/asgard-#{templateItem}.eco"
  return fs.readFileSync __dirname + path, "utf-8"

asgardGet = (msg, url, templateItem) ->
  msg.http(url)
    .get() (err, res, body) ->
      data = JSON.parse(body)
      msg.send response data, getTemplate templateItem

response = (dataIn, template) ->
  return eco.render template, data: dataIn

module.exports = (robot) ->
  #TODO
  robot.hear /^asgard ami/, (msg) ->
    url = getBaseUrl() + 'image/list.json'
    asgardGet msg, url, 'ami'

  robot.hear /^asgard autoscaling ([\w\d]+)$/, (msg) ->
    url = getBaseUrl() + "autoScaling/show/#{msg.match[1]}.json"
    asgardGet msg, url, 'autoscaling'

  #TODO
  robot.hear /^asgard cluster( [\w\d-]+)?$/, (msg) ->
    url = getBaseUrl() + 'cluster/'
    tpl = 'cluster'
    url += if (msg.match[1]) then "show/#{msg.match[1]}.json" else 'list.json'
    tpl += if (msg.match[1]) then '-single' else ''
    asgardGet msg, url, tpl

  robot.hear /^asgard region( ([\w-]+))?$/, (msg) ->
    if msg.match[2]
      region = msg.match[2]
      robot.brain.set 'asgardRegion', region

    msg.send "Region is #{region}."

  robot.hear /^asgard instance$/, (msg) ->
    url = getBaseUrl() + 'instance/list.json'
    asgardGet msg, url, 'instance'

  robot.hear /^asgard instance ([a-zA-Z0-9]+)$/, (msg) ->
    url = getBaseUrl() + "instance/list/#{msg.match[1]}.json"
    asgardGet msg, url, 'instance'

  robot.hear /^asgard instance (i-[a-f0-9]{8})$/, (msg) ->
    url = getBaseUrl() + "instance/show/#{msg.match[1]}.json"
    asgardGet msg, url, 'instance-single'

  #TODO
  robot.hear /^asgard loadbalancer$/, (msg) ->
    url = getBaseUrl() + "loadBalancer/list.json"
    asgardGet msg, url, 'loadbalancer'

  robot.hear /^asgard url( (.*))?$/, (msg) ->
    if msg.match[2]
      asgardUrl = msg.match[2]
      robot.brain.set 'asgardUrl', asgardUrl

    msg.send "URL is #{asgardUrl}."
