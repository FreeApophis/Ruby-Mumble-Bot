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
    @channels = {}
    @users = { }
  end 

  def find_user name
    @users.each do |session, user |
      if user.name == name
        return user
      end
    end
    return nil
  end

  def connect
    super

    send_version
    send_authenticate
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

private

  def update_user(user_state)
  end

  def update_channels(channel_state)
  
  end

  def message_handler message
    case message
      when MumbleProto::UserState
puts message.inspect
        user = @users.fetch(message.session) { |session| user = User.new(message, @users, @channels); }
        user.update(message, @channels)
        follow_apophis
      when MumbleProto::ChannelState
        chan = @channels.fetch(message.channel_id) { |channel_id| chan = Channel.new(message, @root_channel, @channels); }
        chan.update(message)
        @root_channel = chan if !@root_channel
      when MumbleProto::ServerSync
        @session = message.session
        @max_bandwidth = message.max_bandwidth
        @welcome_text = message.welcome_text
        @permissions = message.permissions
        follow_apophis
      when MumbleProto::ContextActionModify
        puts message.inspect
      else
    end
  end
  
  def follow_apophis
    user = find_user "Apophis"
    if user && @session
      send_user_state @session, user.channel.channel_id
    end
  end
end

