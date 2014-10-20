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
#   hubot assign sandbox <name> to <user> - Assign a sandbox to a user
#   hubot I'm using sandbox <name> - Assign a sandbox to yourself
#   hubot release sandbox <name> - Free a sandbox for use by someone else
#   hubot add sandbox <name> - Add a new sandbox
#   hubot delete|remote sandbox <name> - Delete a sandbox
#   hubot show queue - show all of the suckers waiting for the next sandbox
#   hubot queue sandbox - add yourself to the queue for the next released sandbox
#   hubot dequeue|unqueue sandbox - remove youself from the queue
#   hubot remove <user> from queue - remove some jerk from the queue
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
    robot.brain.data.sandboxQueue = new SimpleQueue(robot.brain.data.sandboxQueue || [])


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


  robot.respond /assign s(?:andbox)? ([A-Za-x0-9-_]+) to ([A-Za-x0-9-_ ]+)/i, (msg) ->
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

    # now try and auto-assign the top person in the queue
    queue = robot.brain.data.sandboxQueue
    waiting = queue.dequeue()
    if waiting
      username = robot.brain.userForId(waiting).name
      msg.reply "Auto-assigning sandbox to @" + username
      assignSandbox waiting, sandbox_name, msg


  robot.respond /queue s(?:andbox)?/i, (msg) ->
    queue msg.message.user.id, msg

  robot.respond /(de|un)queue s(?:andbox)?/i, (msg) ->
    dequeue msg.message.user.id, msg

  robot.respond /remove ([A-Za-x0-9-_ ]+) from q(?:ueue)?/i, (msg) ->
    user_id = robot.brain.userForName(msg.match[1])?.id
    dequeue user_id, msg


  robot.respond /show queue/i, (msg) ->
    queue = robot.brain.data.sandboxQueue
    unless queue.peek()
      return msg.send "No one is in the queue"

    human_text = ((i + 1) + ": " + robot.brain.userForId(userId).name for userId, i in queue.items())

    msg.send "Queue:\n" + human_text.join("\n")


  robot.respond /clear queue/i, (msg) ->
    clearQueue()

    msg.send "Queue cleared"


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
    robot.brain.data.sandboxQueue = {}
    clearQueue()
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


  queue = (user_id, msg) ->
    unless robot.brain.data.sandboxQueue.enqueue(user_id)
      return msg.reply "You're already in the queue"

    msg.reply "I added you to the queue"


  dequeue = (user_id, msg) ->
    unless robot.brain.data.sandboxQueue.dequeue(user_id)
      return msg.reply "You're not in the queue"

    msg.reply "Got it"

  clearQueue = () ->
    robot.brain.data.sandboxQueue = new SimpleQueue


class Sandbox
  constructor: (options) ->
    @owner = options.owner
    @modified_dt = options.modified_dt || new Date()

  isFree: ->
    return not @owner

  ownerName: (brain) ->
    return "Nobody" unless @owner
    return brain.userForId(@owner).name

# a very simple queue that doesn't allow duplicates and can be iterated
class SimpleQueue
  constructor: (options) ->
    @_queue = options._queue || []

  enqueue: (item) ->
    if @isQueued item
      return false

    @_queue.push(item)

    return item

  dequeue: (item) ->
    unless (not item or @isQueued item) and @_queue.length isnt 0
      return false

    return @_queue.shift()

  isQueued: (item) ->
    return item in @_queue

  peek: () ->
    return @_queue[0]

  items: () ->
    return @_queue
