#!/usr/bin/ruby
# RubyMumbleBot
# ----------------------

require File.expand_path "../MumbleClient", __FILE__

class Client
  def initialize options, servers
    @options = options
    @servers = servers
    @masters = {}
    @avatars = {}
    @avatar_channels = {}
    @last_connect = Time.at(0)
  end 

  def exit_by_user
    puts ""
    puts "user exited RuMuBo"
  end

  def on_audio client, message
    client.send_udp
  end

  def on_connected_master client, message
    client.switch_channel @masters[client][:channel]
  end

  def on_connected_avatar client, message
    client.switch_channel @avatar_channels[client]
  end

  def on_user_update client, message
    if !message.has_field? :channel_id or client.find_channel(message.channel_id) != client.find_channel(@masters[client][:channel])
      remove_avatar client, message
      return
    end
    if !message.has_field? :session or message.session == client.session
      remove_avatar client, message
      return
    end
    if avatar? client, message.session
      return
    end
    add_avatar client, message
  end

  def avatar? client, session
    user = client.find_user session
    if user.name =~ /@/
      return true
    end
  end

  def add_avatar client, message
    @masters.each do |master, server|
      if client != master
        avatar = MumbleClient.new(server[:host], server[:port], client.users[message.session].name + "@" + server[:host], @options)
        @avatar_channels[avatar] = client.find_channel(server[:channel]).name
        @avatars[master][message.session] = create_avatar(avatar)
        client.log "Create avatar for  #{client.users[message.session].name} in #{client.find_channel(server[:channel]).name}"
      end
    end
    puts @avatars.length
  end

  def remove_avatar client, message
    if !message.has_field? :session
      return
    end
    puts "remove #{message.session}"
    puts @avatars.length
  end

  def on_user_remove client, message
    client.log "Remove Avatar"
  end

  def wait
    if Time.now - @last_connect < 1
      return true
    end
    @last_connect = Time.now
    return false
  end

  def create_master(client)
    while wait
      sleep 0.2
    end

    client.register_handler :ServerSync, method(:on_connected_master)
    client.register_handler :UserState, method(:on_user_update)
    client.register_handler :UserRemove, method(:on_user_remove)
    client.register_handler :UDPTunnel, method(:on_audio)

    client.connect
  end

  def create_avatar(client)
    while wait
      sleep 0.2
    end

    client.register_handler :ServerSync, method(:on_connected_avatar)

    client.connect
  end

  def connected?
    return true
  end

  def run
    @servers.each do |server|
      client = MumbleClient.new(server[:host], server[:port], server[:nick], @options)
      create_master(client)
      @masters[client] = server
      @avatars[client] = {}
    end

    while connected? do
      sleep 0.2
    end
  end
end

