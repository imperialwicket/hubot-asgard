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

createSg = (msg, callback) ->
  sg = {GroupName: sgName, GroupDescription: sgName}
  ec2.request 'CreateSecurityGroup', sg, (error, data) ->
    if error
      callback "Error: #{error.document.Errors.Error}.", null
    else
      console.log data
      msg.send "Created security group #{sgName}(#{data.groupId})."
      callback null, null

runAsgard = (msg, asgardAmi, callback) ->
  instance = {ImageId: asgardAmi, MinCount: 1, MaxCount: 1, SecurityGroup: [sgName], InstanceType: 'm1.small'}
  ec2.request 'RunInstances', instance, (error, data) ->
    if error
      console.log error.document.Errors.Error
      callback "Error: #{error}.", null
    else
      console.log data
      msg.send "Instance pending: #{data}"
      callback null, null

module.exports = (robot) ->
  robot.hear /^asgard-launcher run$/, (msg) ->
    async.series [
      (callback) ->
        sg = robot.brain.get(sgBrain) or 0
        if sg == 0
          console.log("YEP")
          createSg msg, (err, data) ->
            console.log("ERR" + err)
            if err == null
              console.log("NOPE")
              robot.brain.set sgBrain, '1'

            callback err, null
        else
          msg.send "Security group #{sgName} exists."
          callback null
      (callback) ->
        console.log "RUN"
        asgardAmi = robot.brain.get(amiBrain) or netflixossAmi
        runAsgard msg, asgardAmi, (err, data) ->
          callback err
    ], (err, result) ->
      if err
        msg.send "Oops: #{err}"

  robot.hear /^asgard-launcher clear$/, (msg) ->
    robot.brain.remove sgBrain
    robot.brain.remove amiBrain
    msg.send "Cleared saved values for Asgard AMI and Asgard Security Group."

    
