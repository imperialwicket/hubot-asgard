hubot-asgard
============

[Hubot](http://hubot.github.com/) script for interacting with [Asgard](https://github.com/Netflix/asgard)

## Goals
* Allow a an easy interface for quick (particularly read-only) data requests from Asgard. 
* Better mobile support via Campfire/Hipchat/XMPP/etc.
* Templated ([eco](https://github.com/sstephenson/eco)) output allows easy customization for users.
* Support basic and/or fundamental updates that should not require a browser to run.
* Additional ACL via Hubot Admin and roles


## Requirements

[Asgard](https://github.com/Netflix/asgard) needs to be running somewhere, and Hubot needs to be able to access it. Hubot-asgard does not allow self-signed SSL certs, so if you are using an un-altered instance based on [these](http://imperialwicket.com/netflix-asgard-12-ami-updates), make sure to hit port 8080 directly, instead of using the SSL proxy. Also note that Hubot-asgard does not currently support basic authentication, another reason to hit 8080 directly.


## Installation

Until hubot-asgard is more mature, it's not going to be available via npm or github/hubot-scripts. None of the github/hubot-scripts use templates and this seems a little problematic; once the directory structure and more of the core functionality is final, I will get things in npm.

Hubot-asgard requires 'eco' (>= 1.1.0) and 'async' (>= 0.2.9). I'm not doing anything cutting edge, and it will probably work with older versions, but I have not tested them.

For now, you will need to add the src/scripts/asgard.coffee to your Hubot scripts and create the src/templates directory for Hubot. Depending on your configuration, something like this might work:

    HUBOT_DIR=/path/to/hubot/
    cd ~
    git clone https://github.com/imperialwicket/hubot-asgard.git
    cd $HUBOT_DIR
    npm install eco async
    ln -s ~/hubot-asgard/src/scripts/asgard.coffee $HUBOT_DIR/scripts/asgard.coffee
    ln -s ~/hubot-asgard/src/templates/ $HUBOT_DIR/templates


## Configuration options

Hubot-asgard uses Redis to store information via robot.brain. On initial launch, hubot will try to load your HUBOT_ASGARD_URL and HUBOT_ASGARD_REGION from the like-named environment variables. If these are empty, Hubot uses 'http://127.0.0.1' and 'us-east-1'.

You can retrieve and update these values with Hubot via:

    asgard url http://asgard.example.com:8080
    asgard url
    asgard region us-west-2
    asgard region


## Practical Use

Show autoscaling groups:

    asgard autoscaling
    OR
    a as

Show a single autoscaling group:

    a as autoscaling-group-name

Show amis:

    asgard ami

Start a rolling push:

    asgard rollingpush autoscaling-group-name ami-1234abcd

Check the rolling push task:

    asgard task
    asgard task 12


## Todo

* Right now the API wrapping is highest priority; mainly next asg creation and asg edits
* Second is nomenclature and making sure that commands make sense and have consistency
* List size checking, response batching. Need basic safety checks in case someone tries to get the list of all AMIs in us-east-1 (or has very large systems).
* Implement roles - Use HUBOT admin, or entirely separate roles? Probably both.
