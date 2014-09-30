# Description:
#  Keeps track of which developer is using which sandbox
#
# Dependencies:
#   "moment": ""
#
# Configuration:
#  Nothing special
#
# Commands:
#   hubot list|show sandboxes - List the sandboxes and their availability
#   hubot assign sandbox <name> to @<user> - Assign a sandbox to a user
#   hubot I'm using sandbox <name> - Assign a sandbox to yourself
#   hubot release sandbox <name> - Free a sandbox for use by someone else
#   hubot add sandbox <name> - Add a new sandbox
#   hubot delete|remote sandbox <name> - Delete a sandbox
#
# Notes:
#   sandbox names are stored lowercased
#
# Author:
#   christian-blades-cb

moment = require 'moment'

module.exports = (robot) ->

  robot.brain.on 'loaded', =>
    robot.brain.data.sandboxes ||= {}


  robot.respond /(list|show) sandboxes/i, (msg) ->
    sandboxes = robot.brain.data['sandboxes']

    if Object.keys(sandboxes).length == 0
      return msg.send "Sorry, I don't know about any sandboxes"

    human_speak = (name, meta) ->
      if meta.isFree()
        return "* #{name} is free"
      else
        owner_name = meta.ownerName robot.brain
        return "#{name} is in use by #{owner_name} as of #{moment(meta.modified_dt).fromNow()}"

    human_text = (human_speak(name, new Sandbox(meta)) for name, meta of sandboxes)

    msg.send "Sandboxes:\n" + human_text.join("\n")


  robot.respond /assign s(?:andbox)? ([A-Za-x0-9-_]+) to @?([A-Za-x0-9-_]+)/i, (msg) ->
    user_id = robot.brain.userForName(msg.match[2])?.id
    return msg.reply "I have no idea who you're talking about" unless user_id

    sandbox_name = msg.match[1].toString()
    assignSandbox user_id, sandbox_name, msg


  robot.respond /I'm using s(?:andbox)? ([A-Za-z0-9-_]+)/i, (msg) ->
    sandbox_name = msg.match[1].toString()
    assignSandbox msg.message.user.id, sandbox_name, msg


  robot.respond /release s(?:andbox)? ([A-Za-z0-9-_]+)/i, (msg) ->
    sandbox_name = msg.match[1].toString()
    assignSandbox null, sandbox_name, msg


  robot.respond /add s(?:andbox)? ([A-za-z0-9-_]+)/i, (msg) ->
    sandbox_name = msg.match[1].toString().toLowerCase()
    if robot.brain.data.sandboxes[sandbox_name]
      return msg.reply "#{sandbox_name} already exists"

    robot.brain.data.sandboxes[sandbox_name] = new Sandbox(owner: null)
    msg.reply "Done"


  robot.respond /(?:delete|remove) s(?:andbox)? ([A-za-z0-9-_]+)/i, (msg) ->
    sandbox_name = msg.match[1].toString().toLowerCase()
    delete robot.brain.data.sandboxes[sandbox_name]

    msg.reply "It's gone"


  robot.respond /disassemble sandboxes/i, (msg) ->
    robot.brain.data.sandboxes = {}
    msg.send "Bye bye Johnny 5"


  robot.error (err, msg) ->
    robot.logger.error err
    if msg?
      msg.reply "DOES NOT COMPUTE"


  assignSandbox = (user_id, sandbox_name, msg) ->
    robot.logger.debug 1
    sandbox_name = sandbox_name.toString().toLowerCase()
    robot.logger.debug 2

    unless robot.brain.data.sandboxes[sandbox_name]
      return msg.reply "Sorry, I don't know that sandbox"

    robot.brain.data.sandboxes[sandbox_name] = new Sandbox(owner: user_id)

    msg.reply "Got it"


class Sandbox
  constructor: (options) ->
    @owner = options.owner
    @modified_dt = options.modified_dt || new Date()

  isFree: ->
    return not @owner

  ownerName: (brain) ->
    return "Nobody" unless @owner
    return brain.userForId(@owner).name
