#!/usr/bin/ruby
# RubyMumbleBot
# ----------------------

require File.expand_path "../MumbleConnection", __FILE__
require File.expand_path "../MessageHandler", __FILE__
require File.expand_path "../Channel", __FILE__
require File.expand_path "../User", __FILE__

class MumbleClient < MumbleConnection
  attr_accessor :version, :username
  attr_reader :session, :ping_time
  attr_reader :root_channel, :user
  attr_reader :users, :channels
  attr_reader :alpha, :beta, :prefer_alpha, :opus
  attr_reader :key, :client_nonce, :server_nonce
  attr_reader :max_bandwidth, :welcome_text, :allow_html, :message_length, :image_message_length


  def initialize server, port, username, options
    super
    @root_channel
    @channels = { }
    @linked_channels = []
    @users = { }
    @ready = false
    @version = options[:version]
    @event_handler = { }
    @text_handler = { }
    register_local_handlers
  end 

  def register_local_handlers
    register_handler :Version, method(:handle_version)
    register_handler :UDPTunnel, method(:unhandled)
    register_handler :Authenticate, method(:unhandled)
    register_handler :Ping, method(:handle_ping)
    register_handler :Reject, method(:handle_reject)
    register_handler :ServerSync, method(:handle_server_sync)
    register_handler :ChannelRemove, method(:remove_channel)
    register_handler :ChannelState, method(:update_channel)
    register_handler :UserRemove, method(:remove_user)
    register_handler :UserState, method(:update_user)
    register_handler :BanList, method(:unhandled)
    register_handler :TextMessage, method(:handle_text_message)
    register_handler :PermissionDenied, method(:unhandled)
    register_handler :ACL, method(:unhandled)
    register_handler :QueryUser, method(:unhandled)
    register_handler :CryptSetup, method(:handle_crypt_setup)
    register_handler :ContextActionModify, method(:unhandled)
    register_handler :ContextAction, method(:unhandled)
    register_handler :UserList, method(:unhandled)
    register_handler :VoiceTarget, method(:unhandled)
    register_handler :PermissionQuery, method(:unhandled)
    register_handler :CodecVersion, method(:handle_codec_version)
    register_handler :UserStats, method(:unhandled)
    register_handler :RequestBlob, method(:unhandled)
    register_handler :ServerConfig, method(:handle_server_config)
  end

  # State
  @@last_connect = Time.at(0)
  def wait
    return Time.now - @@last_connect < 2
  end

  def connect
    nil while wait

    super

    send_version
    send_authenticate

    @@last_connect = Time.now
  end
  
  def ready?
    return @ready
  end
  
  def channel
    if @user
      return  @user.channel
    end
  end

  # Debug API
  def log message
    puts "[#{@username}] #{message}"
  end

  def inspect
    return "#{user.name} (#{user.session})"
  end

  def debug
    if @options[:debug]
      log @root_channel.tree
    end
  end

  # Register Events Handler
  def register_handler(type, callback)
    if !@event_handler[type]
      @event_handler[type] = []
    end
    @event_handler[type] << callback
  end

  def register_text_handler(prefix, callback)
    if !@text_handler[prefix]
      @text_handler[prefix] = callback
    else
      $stderr.puts "Callback for Textmessage #{prefix} is already registered."
    end
  end

  # Helper API
  def find_channel channel
    channels = @channels.values.select{ |ch| (ch.name == channel) || (ch.channel_id == channel) }
    return channels.first
  end

  def find_user user
    users = @users.values.select{ |u| (u.name == user) || (u.session == user) }
    return users.first
  end

  # Highlevel Commands Myself (usually allowed by server)
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

  # Highlevel Commands on Others (usually disallowed by server)
  def move_user user, channel
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

private

  # Generic Handler, Dispatcher
  def message_handler message
    handler = @event_handler[message.class.to_s.split(":")[2].to_sym]
    if handler
      handler.each do |h|  
        log "handle #{message.class} with #{h.name}" if @options[:debug]
        h.call(self, message)
      end
    end
  end

  def handle_text_message(client, message)
    text = message.message.to_s
    prefix = text.split(" ").first
    handler = @text_handler[prefix]

    if handler
      log "handle '#{prefix}' with #{handler.name}" if @options[:debug]
      handler.call(self, message)
    end
  end

  def unhandled(client, message)
    log "*** unhandled ***"
    log message.inspect
  end

  # Specific Handlers 
  def handle_version(client, message)
    @server_version = message.version
    @server_release = message.release
    @server_os = message.os
    @server_os_version = message.os_version

    log "Server: #{@server_release} (#{@server_os_version})"
  end

  def handle_ping(client, message)
    if (message.timestamp == @last_ping[:ts])
      @ping_time = 1000 * (Time.now - @last_ping[:ping])
    end
  end

  def handle_reject(client, message)
    $stderr.puts "Mumble server '#{@server}:#{@port}' rejected '#{@username}'. EXIT"
    $stderr.puts "Reason: #{message.reason}"
    exit
  end

  def handle_server_sync(client, message)
    @max_bandwidth = message.max_bandwidth if message.has_field? :max_bandwidth
    @welcome_text = message.welcome_text if message.has_field? :welcome_text
    @permissions = message.permissions if message.has_field? :permissions

    if message.has_field? :session
      @session = message.session 
      @user = @users[@session]
    end

    @ready = true
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
    channel = @channels.fetch(message.channel_id) { |channel_id| channel = Channel.new(message, @root_channel, @channels); }
    channel.update(message)

    @root_channel = channel if !@root_channel
  end

  def remove_channel(client, message)
    channel = @channels[message.channel_id]
    channel.remove
  end

  def handle_crypt_setup(client, message)
    @key = message.key
    @server_nonce = message.server_nonce
    @client_nonce = message.client_nonce
  end

  def handle_codec_version(client, message)
    @alpha = message.alpha
    @beta = message.beta
    @prefer_alpha = message.prefer_alpha
    @opus = message.opus
  end

  def handle_server_config(client, message)
    @max_bandwidth = message.max_bandwidth if message.has_field? :max_bandwidth
    @welcome_text = message.welcome_text if message.has_field? :welcome_text
    @allow_html = message.allow_html if message.has_field? :allow_html
    @message_length = message.message_length if message.has_field? :message_length
    @image_message_length = message.image_message_length if message.has_field? :image_message_length
  end
end

