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
#   aws-sdk
#   async
#
# Configuration:
#   process.env.AWS_ACCESS_KEY_ID
#   process.env.AWS_SECRET_ACCESS_KEY
#
# Commands:
#   asgard-launcher run - Launches an m1.small Asgard instance
#   asgard-launcher authorize <ip> - Authorize an IP address to access instance
#   asgard-launcher create ami - Creates an AMI from a running Asgard instance
#   asgard-launcher terminate - Terminate the Asgard instance (based on Tag:Name)
#   asgard-launcher url - Get the PublicDnsName for instance with Tag:Name=asgard-hubot
#   asgard-launcher clear - Use clear to wipe saved data.
#   asgard-launcher instance type <instanceType> - Override default m1.small instance type
#   asgard-launcher ami <ami-id> - Override default ami (NetflixOSS release or hubot-asgard generated ami)
#
# Author:
#   imperialwicket

netflixossAmi = 'ami-1889f771'
asgardAmi = netflixossAmi
instanceType = 'm1.small'
sgName = imageName = instanceName = 'asgard-hubot'
brain = { image: 'asgardAmi', instanceType: 'asgardInstanceType' }
debug = true

async = require 'async'
aws = require 'aws-sdk'

aws.config.update {region: 'us-east-1'}
ec2 = new aws.EC2

log = (event) ->
  if debug
    console.log event

createSg = (msg, callback) ->
  sg = {GroupName: sgName, Description: sgName}
  req = ec2.createSecurityGroup(sg)
    .on('error', (response) ->
      log "ERROR: #{response}"
      cbResponse = if (response.toString().indexOf("Duplicate") != -1) then null else response
      callback(cbResponse, null))
    .on('success', (response) ->
      log response.data
      msg.send "Created security group #{sgName} (#{response.data.GroupId})."
      callback(null, null))
    .send()

runAsgard = (msg, asgardAmi, instanceType, callback) ->
  instance = {ImageId: asgardAmi, MinCount: 1, MaxCount: 1, SecurityGroups: [sgName], InstanceType: instanceType}
  req = ec2.runInstances(instance)
    .on('error', (response) ->
      log "ERROR: #{response}"
      callback(response, null))
    .on('success', (response) ->
      log response.data
      # Assuming one instance returned in instanceSet...
      instanceId = response.data.Instances[0].InstanceId
      msg.send "Pending instance #{instanceId} is launching based on #{asgardAmi}."
      msg.send "Use 'asgard-launcher url' to retrieve the PublicDnsName."
      callback(null, {InstanceId: instanceId}))
    .send()

authorizeIp = (msg, ip) ->
  ingress = {GroupName: sgName, IpPermissions: [{IpProtocol: 'tcp', FromPort: 8080, ToPort: 8080, IpRanges: [{CidrIp: ip}]}]}
  req = ec2.authorizeSecurityGroupIngress(ingress)
    .on('error', (response) ->
      log("ERROR: #{response}"))
    .on('success', (response) ->
      log response.data
      msg.send("Authorized access to #{sgName} over port 8080 to #{ip}."))
    .send()

addInstanceNameTag = (msg, instanceId, callback) ->
  tag = {Resources: [instanceId], Tags: [{Key: 'Name', Value: instanceName}]}
  req = ec2.createTags(tag)
    .on('error', (response) ->
      log "ERROR: #{response}"
      callback(response, null))
    .on('success', (response) ->
      log response.data
      msg.send "Added tag Name=#{instanceName} to instance #{instanceId}"
      callback(null, {InstanceId: instanceId}))
    .send()

getInstanceIds = (msg, callback) ->
  params = { Filters : [ { Name: 'tag:Name', Values: [instanceName] } ] }
  req = ec2.describeInstances(params)
    .on('error', (response) ->
      log "ERROR: #{response}"
      callback(response, null))
    .on('success', (response) ->
      log response.data
      instanceId = response.data.Reservations[0].Instances[0].InstanceId
      msg.send "Found instance: #{instanceId}"
      callback(null, {InstanceId: instanceId}))
    .send()

getInstancePublicDnsName = (msg, callback) ->
  params = { Filters : [ { Name: 'tag:Name', Values: [instanceName] } ] }
  req = ec2.describeInstances(params)
    .on('error', (response) ->
      log "ERROR: #{response}"
      callback(response, null))
    .on('success', (response) ->
      # Assume one reservation and one instance returned; shouldn't do this...
      log response.data
      if response.data.Reservations[0].Instances[0].PublicDnsName?
        url = response.data.Reservations[0].Instances[0].PublicDnsName
        msg.send "Asgard is loading at http://#{url}:8080/"
        msg.send "Use 'asgard url http://#{url}:8080/' to save this dns value for hubot-asgard."
        msg.send "Use 'asgard-launcher authorize <YOUR_IP>' to update the asgard-hubot security group and allow access over 8080 to your ip."
        msg.send "After entering your AWS config data, use 'asgard-launcher create ami' to generate a private and configured AMI (it is recommended to DISABLE the public Amazon images options for hubot-asgard)."
      else
        msg.send '[PublicDnsName is not yet available]'

      callback(null, url))
    .send()

createImage = (msg, instanceId, callback) ->
  name = imageName + '-' + + new Date().getTime()
  params = {InstanceId: instanceId, Name: name}
  req = ec2.createImage(params)
    .on('error', (response) ->
      log "ERROR: #{reponse}"
      callback(response, null))
    .on('success', (response) ->
      log response.data
      msg.send "Created AMI #{response.data.ImageId}."
      callback(null, {ImageId: response.data.ImageId}))
    .send()

terminateInstances = (msg, instanceId, callback) ->
  req = ec2.terminateInstances({InstanceIds: [instanceId]})
    .on('error', (response) ->
      log "ERROR: #{response}"
      callback(response, null))
    .on('success', (response) ->
      log response.data
      msg.send "Terminated instance: #{instanceId}"
      callback(null, null))
    .send()

module.exports = (robot) ->
  # Set an instance type for launching
  robot.hear /^asgard-launcher instance type ([\w\d\.]+)$/, (msg) ->
    if msg.match[1]
      instanceType = msg.match[1]
      robot.brain.set brain.instanceType, instanceType

    msg.send "Instance type is #{instanceType}."

  # Set a custom AMI for launching
  robot.hear /^asgard-launcher ami (ami-[a-f0-9]{8})$/, (msg) ->
    if msg.match[1]
      asgardAmi = msg.match[1]
      robot.brain.set brain.image, asgardAmi

    msg.send "Image (AMI) is #{asgardAmi}."

  # Create a security group and launch an Asgard ami with the new security group
  robot.hear /^asgard-launcher run$/, (msg) ->
    async.waterfall [
      (callback) ->
        createSg msg, callback
      (_, callback) ->
        asgardAmi = robot.brain.get(brain.image) or asgardAmi
        asgardInstanceType = robot.brain.get(brain.instanceType) or instanceType
        runAsgard msg, asgardAmi, asgardInstanceType, callback
      (data, callback) ->
        addInstanceNameTag msg, data.InstanceId, callback
    ], (err, result) ->
      if err
        msg.send "Oops: #{err}"

  # Clear the brain entries for asgard-launcher
  robot.hear /^asgard-launcher clear$/, (msg) ->
    robot.brain.remove brain.image
    msg.send "Cleared saved values for Asgard AMI and Asgard Security Group."

  # Get the PublicDnsName based on tag:Name=<instanceName>
  robot.hear /^asgard-launcher url$/, (msg) ->
    async.waterfall [
      (callback) ->
        getInstancePublicDnsName msg, callback
    ], (err, result) ->
      if err
        msg.send "Oops: #{err}"

  # Update the security group 'asgard-hubot' to allow access to 8080 for <ip>
  robot.hear /^asgard-launcher authorize ([\d/\.+]{7,18})$/, (msg) ->
    ip = if (msg.match[1].indexOf('/') == -1) then "#{msg.match[1]}/32" else msg.match[1]
    authorizeIp(msg, ip)

  robot.hear /^asgard-launcher terminate$/, (msg) ->
    async.waterfall [
      (callback) ->
        getInstanceIds msg, callback
      (data, callback) ->
        terminateInstances msg, data.InstanceId, callback
    ], (err, result) ->
      if err
        msg.send "Oops: #{err}"

  # Create an AMI based on the current asgard-hubot instance
  robot.hear /^asgard-launcher create ami$/, (msg) ->
    async.waterfall [
      (callback) ->
        getInstanceIds msg, callback
      (data, callback) ->
        createImage msg, data.InstanceId, callback
      (data, callback) ->
        robot.brain.set brain.image, data.ImageId
        callback
    ], (err, result) ->
      if err
        msg.send "Oops: #{err}"
