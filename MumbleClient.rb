#!/usr/bin/ruby
# RubyMumbleBot
# ----------------------

require File.expand_path "../MumbleConnection", __FILE__
require File.expand_path "../MessageHandler", __FILE__
require File.expand_path "../Channel", __FILE__
require File.expand_path "../User", __FILE__

class MumbleClient < MumbleConnection
  attr_accessor :version, :username
  attr_reader :session
  attr_reader :root_channel, :user
  attr_reader :users, :channels
  attr_reader :alpha, :beta

  def initialize server, port, username, options
    super
    @root_channel
    @channels = { }
    @linked_channels = []
    @users = { }
    @ready = false
    @version = options[:version]
    @event_handler = { }
    register_local_handlers
  end 

  def register_local_handlers
    register_handler :UserState, method(:update_user)
    register_handler :UserRemove, method(:remove_user)
    register_handler :ChannelState, method(:update_channel)
    register_handler :ServerSync, method(:handle_server_sync)
    register_handler :TextMessage, method(:handle_text_message)
    register_handler :CodecVersion, method(:handle_codec_version)
    register_handler :Reject, method(:handle_reject)
    register_handler :UserStats, method(:handle_user_stats)
  end 

  @@last_connect = Time.at(0)
  def wait
    return Time.now - @@last_connect < 2
  end

  def connect
    while wait
    end

    super

    send_version
    send_authenticate

    @@last_connect = Time.now
  end
  
  def ready?
    return @ready
  end
  
  def debug
    if @options[:debug]
      @root_channel.print_tree
    end
  end

  def log message
    puts "[#{@username}] #{message}"
  end

  def channel
    if @user
      return  @user.channel
    end
  end

  def send_authenticate
    super @username
  end

  def send_version
    super @version
  end

  def mute state
    send_user_state @session, nil, state, nil
  end

  def deaf state
    send_user_state @session, nil, nil, state
  end

  def switch_channel channel
    channel = find_channel(channel)

    send_user_state @session, channel.channel_id, nil, nil
  end

  def send_channel_message channel, message, recursive = false
    channel = find_channel(channel)
    if recursive
      send_text_message @session, message, nil, nil, channel.channel_id
    else
      send_text_message @session, message, nil, channel.channel_id
    end
  end

  def send_user_message user, message
    user = find_user(user)
    if user
      send_text_message @session, message, user.session
    end
  end

  @event_handler

  def register_handler(type, callback)
    if !@event_handler[type]
      @event_handler[type] = []
    end
    @event_handler[type] << callback
  end

  def find_channel channel
    channels = @channels.values.select{ |chan| (chan.name == channel) || (chan.channel_id == channel) }
    return channels.first
  end

  def find_user user
    users = @users.values.select{ |u| (u.name == user) || (u.session == user) }
    return users.first
  end

  def inspect
    return "#{user.name} (#{user.session})"
  end

private

  def message_handler message
    handler = @event_handler[message.class.to_s.split(":")[2].to_sym]
    if handler
      handler.each do |h|  
        log "handle #{message.class} with #{h.name}" if @options[:debug]
        h.call(self, message)
      end
    end
  end
  
  def update_user(client, message)
    user = @users.fetch(message.session) do |session| 
      user = User.new(message, @users, @channels)
    end
    user.update(message, @channels)
  end

  def remove_user(client, message)
    user = @users[message.session]
    user.remove
  end

  def update_channel(client, message)  
    chan = @channels.fetch(message.channel_id) { |channel_id| chan = Channel.new(message, @root_channel, @channels); }
    chan.update(message)

    @root_channel = chan if !@root_channel
  end

  def handle_server_sync(client, message)
    @session = message.session
    @max_bandwidth = message.max_bandwidth
    @welcome_text = message.welcome_text
    @permissions = message.permissions

    @user = @users[session]
 
    @ready = true
  end

  def handle_codec_version(client, message)
    @alpha = message.alpha
    @beta = message.beta
    @prefer_alpha = message.prefer_alpha
    @ops = message.opus
  end

  def handle_reject(client, message)
  end

  def handle_user_stats(client, message)
  end

  def handle_text_message(client, message)
    log "Message from #{@users[message.actor].name}"

    message.channel_id.each do |channel_id|
      log "Message to channel #{@channels[channel_id].name}"
    end
    message.tree_id.each do |tree_id|
      log "Message to channel #{@channels[tree_id].name} and all subchannels"
    end
    message.session.each do |session|
      log "Message to user #{@users[session].name}"
      if @session = session
        log "Thats me"
      else
        log "BAD: Thats not me"
      end
    end

    text = message.message.to_s

    if text.match /^!find/
      nick = text[6..-1]
      user = find_user nick
      if user
        send_user_message message.actor, "User '#{user.name}' is in Channel '#{user.channel.path}'"
      else
        send_user_message message.actor, "There is no user '#{nick}' on the Server"
      end
    end
  end
end

