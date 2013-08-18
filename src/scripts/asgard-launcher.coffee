# Description:
#   Asgard Launcher provides hubot commands for common AWS-specific Asgard
#   needs.
#
#   Asgard run will attempt to launch an instance configured with this script,
#   and use a security group created by this script. If it does not find these,
#   a security group ('asgard-hubot') is generated, and the NetflixOSS Asgard
#   AMI is used to launch a new instance. Use `asgard-launcher authorize <IP>`
#   to allow access to your instance for a particular IP. After entering your
#   AWS account id, access key, and secret key, use `asgard-launcher create ami`
#   to save a new private AMI ('asgard-hubot') with your configuration included.
#   Use `asgard-launcher terminate` to shut down the running instance with Tag:
#   Name='asgard-hubot'.
#
#   This script assumes AWS objects it creates will persist. If you delete the
#   AWS objects created by Asgard-Launcher, you should issue
#   `asgard-launcher clear` so that Asgard-Launcher knows to re-create the
#   necessary Security Group and launch from the NetflixOSS AMI again.
#
# Dependencies:
#   aws2js
#   async
#
# Configuration:
#   process.env.HUBOT_AWS_ACCESS_KEY
#   process.env.HUBOT_AWS_SECRET_KEY
#
# Commands:
#   asgard-launcher run - Launches an m1.small Asgard instance
#   asgard-launcher authorize <IP> - Authorize an IP address to access instance
#   asgard-launcher create ami - Creates an AMI from a running Asgard instance
#   asgard-launcher terminate - Terminate the Asgard instance (based on Tag:Name)
#   asgard-launcher clear - Use clear to wipe saved data.
#
# Author:
#   imperialwicket

netflixossAmi = 'ami-1889f771'
sgName = 'asgard-hubot'
sgBrain = 'asgardSg'
amiName = 'asgard-hubot'
amiBrain = 'asgardAmi'

async = require 'async'
aws = require 'aws2js'

ec2 = aws
  .load('ec2', process.env.HUBOT_AWS_ACCESS_KEY, process.env.HUBOT_AWS_SECRET_KEY)
  .setApiVersion('2013-06-15')
  .setRegion('us-east-1')

asgardSg = robot.brain.get(sgBrain) * 1 or 0
asgardAmi = robot.brain.get(amiBrain) or netflixossAmi

createSg = (msg, callback) ->
  if robot.brain.get 'asgardSg'
    sg = {groupName: sgName, Description: sgName}
    sgResponse = ''
    ec2.request 'createSecurityGroup', sg, (error, data) ->
      if error
        console.log error
        callback "Error: #{error}."
      else
        sgResponse = data.GroupId
        robot.brain.set sgBrain, 1
        msg.send "Created security group #{sgResponse}."
        callback
  else
    msg.send "Security group #{sgName} exists."
    callback

runAsgard = (msg, callback) ->
  instance = {ImageId: asgardAmi, MinCount: 1, MaxCount: 1, SecurityGroups: [asgardSg], InstanceType: 'm1.small'}
  ec2.request 'runInstances', instance, (error, data) ->
    if error
      console.log error
      callback "Error: #{error}."
    else
      msg.send "Instance pending: #{data.Instances[0].PublicDnsName}"
      callback

clearBrain = (msg) ->
  robot.brain.remove sgBrain
  robot.brain.remove amiBrain
  msg.send "Cleared saved values for Asgard AMI and Asgard Security Group."

module.exports = (robot) ->
  robot.hear /^asgard run$/, (msg) ->
    async.series [
      (callback) ->
        createSg msg, (err, data) ->
          callback err
      (callback) ->
        runAsgard msg, (err, data) ->
          callback err
    ], (err, result) ->
      if err
        msg.send "Oops: #{err}"

