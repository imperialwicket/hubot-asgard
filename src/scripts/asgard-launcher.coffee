# Description:
#   Asgard Launcher provides hubot commands for common AWS-specific Asgard
#   instance needs (launching an Asgard instance, configuring its security
#   group, etc.).
#
#   `asgard run` will attempt to launch an instance configured with this script,
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
sgName = amiName = instanceName = 'asgard-hubot'
sgBrain = 'asgardSg'
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
  #TODO Use the IpPermissions object to configure security group and not this
  # deprecated input object
  instance = {ImageId: asgardAmi, MinCount: 1, MaxCount: 1, SecurityGroup: [sgName], InstanceType: 'm1.small'}
  ec2.request 'RunInstances', instance, (error, data) ->
    if error
      console.log error.document.Errors.Error
      callback "Error: #{error}.", null
    else
      console.log data
      msg.send "Instance pending: #{data.instanceSet.instanceId}"
      callback null, data.instanceSet.instanceId

authorizeIp = (msg, ip) ->
  ingress = {GroupName: sgName, IpProtocol: 'tcp', FromPort: '8080', ToPort: '8080', CidrIp: ip }
  ec2.request 'AuthorizeSecurityGroupIngress', ingress, (error, data) ->
    if error
      console.log error.document.Errors.Error
    else
      msg.send "Authorized access to #{sgName} over port 8080 to #{ip}."

addInstanceNameTag = (msg, instanceId, callback) ->
  tag = {Resources: [instanceId], Tags:[{Key: 'Name', Value: instanceName}]}
  ec2.request 'CreateTags', tag, (error, data) ->
    if error
      console.log error.document.Errors
    else
      msg.send "Added tag Name=#{instanceName} to instance #{instanceId}"

    callback

getInstancePublicDnsName = (msg, instanceId, callback) ->
  params = { Filters : [ { Name : 'InstanceId', Values : [instanceId] } ] }
  ec2.request 'DescribeInstances', params, (error, data) ->
    if error
      console.log error.document.Errors
    else
      # Assuming one reservation and one instance returned; shouldn't do this...
      url = data.Reservations[0].Instances[0].PublicDnsName
      msg.send "Asgard is loading at #{url}"
      msg.send "You can use 'asgard url #{url}:8080', if you want to save this dns value."

module.exports = (robot) ->
  # Create a security group and launch an Asgard ami with the new security group
  robot.hear /^asgard-launcher run$/, (msg) ->
    async.waterfall [
      (callback) ->
        sg = robot.brain.get(sgBrain) or 0
        if sg == 0
          createSg msg, (err, data) ->
            if err == null
              robot.brain.set sgBrain, '1'

            callback err, null
        else
          msg.send "Security group #{sgName} exists."
          callback null
      (callback) ->
        asgardAmi = robot.brain.get(amiBrain) or netflixossAmi
        runAsgard msg, asgardAmi, (err, data) ->
          callback err, data
      (callback, instanceId) ->
        addInstanceNameTag msg, instanceId, (err, data) ->
          callback err, instanceId
      (callback, instanceId) ->
        getInstancePublicDnsName msg, instanceId, (err, data) ->
          callback err, null
    ], (err, result) ->
      if err
        msg.send "Oops: #{err}"

  # Clear the brain entries for asgard-launcher
  robot.hear /^asgard-launcher clear$/, (msg) ->
    robot.brain.remove sgBrain
    robot.brain.remove amiBrain
    msg.send "Cleared saved values for Asgard AMI and Asgard Security Group."

  # Update the security group 'asgard-hubot' to allow access to 8080 for <ip>
  robot.hear /^asgard-launcher authorize ([\d/\.+]{7,18})$/, (msg) ->
    ip = if (msg.match[1].indexOf('/') == -1) then "#{msg.match[1]}/32" else msg.match[1]
    authorizeIp(msg, ip)
