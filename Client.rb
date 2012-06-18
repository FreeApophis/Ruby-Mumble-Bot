#!/usr/bin/ruby
# RubyMumbleBot
# ----------------------

require File.expand_path "../MumbleClient", __FILE__

class Client
  def initialize options
    @mastercount = 0
    @options = options
    @masters = {}
    @slave_by_host = {}
    @slave_by_user = {}
    @server_by_client = {}
  end 

  def exit_by_user
    puts ""
    puts "user exited RuMuBo"
    @masters.keys.first.debug
  end

  def connected?
    return true
  end

  def make_master client
    client.register_handler :ServerSync, method(:on_connected)
    client.register_handler :UserState, method(:on_users_changed)
    client.register_handler :UserRemove, method(:on_users_changed)
    client.register_handler :UDPTunnel, method(:on_audio)

    @text_handler = MessageHandler.new client

    client.connect
    return client
  end

  def make_slave client
    client.register_handler :ServerSync, method(:on_connected)

    client.connect
    return client
  end

  def on_connected client, message
    if @masters.include?(client)
      client.switch_channel @masters[client][:channel]
    else
      master = @server_by_client[client]
      @slave_by_host[master][message.session] = client
      client.switch_channel @masters[master][:channel]
    end
  end

  def on_users_changed client, message
    return if !client.channel
    
    client.channel.localusers.each do |u|
      if u.session == client.user.session
        next # this is the master
      end

      if !@slave_by_host[client] or @slave_by_host[client][u.session]
        next # this is a slave from another server
      end

      if !@slave_by_user[client] or @slave_by_user[client][u.session]
        update_slaves(client, u)
        next # we have already slaves for this one
      end
 
      # new user
      @masters.each do |master, config|
        next if master == client # thats the current server
        host = @masters[client][:host]
        slave = make_slave MumbleClient.new(config[:host], config[:port], "#{u.name}@#{host}", @options)
        @slave_by_user[client][u.session] = [] if  !@slave_by_user[client][u.session]
        @slave_by_user[client][u.session] << slave
        @server_by_client[slave] = master
      end
    end

    #is a user missing? -> disconnect all slaves
    @slave_by_user[client].each do |session, slaves|
      is_in_channel = false
      client.channel.localusers.each do |u|
        is_in_channel = true if (session == u.session)
      end
      if !is_in_channel
        slaves.each do |slave|
          slave.disconnect
          remove_slave(slave, client)
        end
      end
    end
  end

  def update_slaves master, real_user
    slaves = @slave_by_user[master][real_user.session]

    return if !slaves.first.user # not ready yet

    if real_user.self_mute != slaves.first.user.self_mute
      slaves.each do |slave|
        slave.mute real_user.self_mute
      end
    end

    if real_user.self_deaf != slaves.first.user.self_deaf
      slaves.each do |slave|
        slave.deaf real_user.self_deaf
      end
    end
  end

  def remove_slave slave, master
    @slave_by_host[@server_by_client[slave]].delete(slave.session)

    delete_session = nil
    @slave_by_user[master].each do |session, clients|
      if clients.include?(slave)
        delete_session = session
      end
    end
    if delete_session
      @slave_by_user[master].delete(delete_session)
    end

    @server_by_client.delete(slave)
  end

  def on_audio client, message
    packet = message.packet

    index = 0
    tt = Tools.decode_type_target(packet[index])
    index = 1

    vi1 = Tools.decode_varint packet, index
    index = vi1[:new_index]
    session = vi1[:result]

    vi2 = Tools.decode_varint packet, index
    index = vi2[:new_index]
    sequence = vi2[:result]

    data = packet[index..-1]

    slaves = @slave_by_user[client][session]

    #is from real user?
    return if !slaves

    codec_type = tt[:type]

    slaves.each do |slave|
      if (codec_type == 0) or (codec_type == 3)
        tt[:type] = (client.alpha == slave.alpha) ? codec_type : 3 - codec_type
      end
      repackaged = Tools.encode_type_target(tt) + Tools.encode_varint(sequence) + data
      slave.send_udp_tunnel repackaged
    end
  end

  def run servers
    servers.each do |server|
      @mastercount += 1
      client = MumbleClient.new(server[:host], server[:port], server[:nick], @options)
      make_master(client)
      @masters[client] = server
      @slave_by_host[client] = {}
      @slave_by_user[client] = {}
    end

    while connected? do
      sleep 0.2
    end
  end
end

