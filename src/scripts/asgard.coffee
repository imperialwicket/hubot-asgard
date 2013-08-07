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
#   asgard url [URL] - Get/set the asgard base url
#   asgard region [REGION] - Get/set the asgard region
#   asgard instance - List instances per region
#   asgard instance APP - List instances per app per region
#   asgard instance ID - Show details for instance ID (i-[a-f0-9])
#   asgard autoscaling NAME - Show details for autoscaling group NAME
#   asgard cluster NAME - Show details for cluster NAME
#   asgard ami - List AMIs per region (careful if public enabled) 
#

baseUrl = process.env.HUBOT_ASGARD_URL or 'http://127.0.0.1'
region = process.env.HUBOT_ASGARD_REGION or 'us-east-1'

eco = require "eco"
fs  = require "fs"

getTemplate = (templateItem) ->
  return fs.readFileSync __dirname + "../templates/asgard-#{templateItem}.eco", "utf-8"

asgardGet = (msg, url, templateItem) ->
  msg.http(url)
    .get() (err, res, body) ->
      data = JSON.parse(body)
      dataArray = [].concat data
      msg.send response dataArray, getTemplate templateItem

response = (dataIn, template) ->
  console.log dataIn
  return eco.render template, data: dataIn

module.exports = (robot) ->
  robot.hear /^asgard url( (.*))?$/, (msg) ->
    if msg.match[2]
      baseUrl = msg.match[2]
      robot.brain.set 'asgardUrl', baseUrl

    msg.send 'URL is #{baseUrl}.'

  robot.hear /^asgard region( ([\w-]+))?$/, (msg) ->
    if msg.match[2]
      region = msg.match[2]
      robot.brain.set 'asgardRegion', region

    msg.send 'Region is #{region}.'

  robot.hear /^asgard instance$/, (msg) ->
    url = baseUrl + '/' + region + '/instance/list.json'
    asgardGet msg, url, 'instance'

  robot.hear /^asgard instance ([a-zA-Z0-9]+)$/, (msg) ->
    url = "#{baseUrl}/#{region}/instance/list/#{msg.match[1]}.json"
    asgardGet msg, url, 'instance'

  robot.hear /^asgard instance (i-[a-f0-9]{8})$/, (msg) ->
    url = "#{baseUrl}/#{region}/instance/show/#{msg.match[1]}.json"
    asgardGet msg, url, 'instance-full'

  robot.hear /^asgard autoscaling ([a-z]+)$/, (msg) ->
    url = "#{baseUrl}/#{region}/autoScaling/show/#{msg.match[1]}.json"
    asgardGet msg, url, 'autoscaling'

  robot.hear /^asgard cluster ([\w\d]+)$/, (msg) ->
    url = "#{baseUrl}/#{region}/cluster/show/#{msg.match[1]}.json"
    asgardGet msg, url, 'cluster'

