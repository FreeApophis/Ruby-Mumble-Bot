#!/usr/bin/ruby
# RubyMumbleBot
# ----------------------

require File.expand_path "../MumbleConnection", __FILE__
require File.expand_path "../Channel", __FILE__
require File.expand_path "../User", __FILE__

class MumbleClient < MumbleConnection
  attr_accessor :version, :username
  attr_reader :session

  def initialize server, port, options
    super
    @root_channel
    @channels = { }
    @users = { }
    @ready = false
  end 

  def connect
    super

    send_version
    send_authenticate
  end
  
  def ready?
    return @ready
  end
  
  def debug
    if @options[:debug]
      @root_channel.print_tree
    end
  end

  def send_authenticate
    super @username
  end

  def send_version
    super @version
  end

  def switch_channel channel
    channel = find_channel(channel)

    send_user_state @session, channel.channel_id
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
    send_text_message @session, message, find_user(user).session
  end

private

  def find_user user
    users = @users.values.select{ |u| (u.name == user) || (u.session == user) }
    raise "User not found" if (users.length == 0)

    return users.first
  end

  def find_channel channel
    channels = @channels.values.select{ |chan| (chan.name == channel) || (chan.channel_id == channel) }
    raise "Channel not found" if (channel.length == 0)

    return channels.first
  end

  def message_handler message
    case message
      when MumbleProto::UserState
puts message.inspect
        update_users(message)
        follow_apophis
      when MumbleProto::ChannelState
        update_channels(message)  
      when MumbleProto::ServerSync
        handle_server_sync(message)
        follow_apophis
      when MumbleProto::TextMessage
        handle_text_message (message)
      when MumbleProto::ContextActionModify
        puts message.inspect
      else
    end
  end
  
  def update_users(message)
    user = @users.fetch(message.session) { |session| user = User.new(message, @users, @channels); }
    user.update(message, @channels)
  end

  def update_channels(message)  
    chan = @channels.fetch(message.channel_id) { |channel_id| chan = Channel.new(message, @root_channel, @channels); }
    chan.update(message)

    @root_channel = chan if !@root_channel
  end

  def handle_server_sync message
    @session = message.session
    @max_bandwidth = message.max_bandwidth
    @welcome_text = message.welcome_text
    @permissions = message.permissions
 
   @ready = true
  end

  def handle_text_message(message)
    puts "Message from #{@users[message.actor].name}"

    message.channel_id.each do |channel_id|
      puts "Message to channel #{@channels[channel_id].name}"
    end
    message.tree_id.each do |tree_id|
      puts "Message to channel #{@channels[tree_id].name} and all subchannels"
    end
    message.session.each do |session|
      puts "Message to user #{@users[session].name}"
      if @session = session
        puts "Thats me"
      else
        puts "BAD: Thats not me"
      end
    end
    puts message.inspect
  end

  def follow_apophis
    begin
      user = find_user "Apophis"
      if user && @session
        send_user_state @session, user.channel.channel_id
      end
    rescue
    end
  end
end

