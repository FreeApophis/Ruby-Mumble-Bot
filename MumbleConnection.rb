#!/usr/bin/ruby
# RubyMumbleBot
# ----------------------

require File.expand_path "../MessageTypes", __FILE__
require File.expand_path "../Tools", __FILE__

class MumbleConnection
  def initialize server, port, options
    @server = server
    @port = port
    @options = options
    load_keys
    @connected = false
    @mumble_version = (1 << 16) + (2 << 8) + 3
  end

  def connected?
    return @connected
  end

  def connect

    socket = TCPSocket.new(@server, @port)

    #requires TLS 1 / SSL fails
    ssl_context = OpenSSL::SSL::SSLContext.new(:TLSv1)
    ssl_context.verify_mode = OpenSSL::SSL::VERIFY_NONE
    ssl_context.key = @key

    @ssl_socket = OpenSSL::SSL::SSLSocket.new(socket, ssl_context)
    @ssl_socket.sync_close = true
    @ssl_socket.connect

    STDERR.print "SSLSocket connected.\n" if @options[:debug]
    STDERR.print @ssl_socket.peer_cert.to_text, "\n" if @options[:debug]

    @connected = true

    @udp_socket = UDPSocket.new
    @udp_socket.connect(@server, @port)

    Thread.new { listen }
    Thread.new { pinger }
    Thread.new { udp_pinger }
  end

  def send_version client_version
    message = MumbleProto::Version.new
    message.release = client_version
    message.version = @mumble_version
    message.os = Tools.platform
    message.os_version = RUBY_PLATFORM

    mumble_write(message)
  end

  def send_authenticate username
    message = MumbleProto::Authenticate.new
    message.username = username  
    message.celt_versions << -2147483637

    mumble_write(message)
  end

  def send_ban_list bans, query
    message = MumbleProto::BanListNew.new
    message.bans = bans if bans != nil
    message.query = query

    mumble_write(message)
  end

  def channel_remove channel_id
    message = MumbleProto::ChannelRemove.new
    message.channel_id = channel_id

    mumble_write(message)
  end

  def permission_query channel_id, permissions, flush
    message = MumbleProto::PermissionQuery.new
    message.channel_id = channel_id if channel_id != nil
    message.permission = permissions if permissions != nil
    message.flush = flush if flush != nil

    mumble_write(message)  
  end

  def send_text_message actor, session, channel_id, tree_id, message
    message = MumbleProto::TextMessage.new
    message.actor = actor
    message.session = session
    message.channel_id = channel_id
    message.message = tree_id
    message.message = message

    mumble_write(message)
  end


  def send_request_blob session_texture, session_comment, channel_description
    message = MumbleProto::RequestBlob.new
    message.session_texture = session_texture
    message.session_comment = session_comment
    message.channel_description = channel_description

    mumble_write(message)
  end

  def send_ping timestamp = nil
    message = MumbleProto::Ping.new
    message.timestamp = timestamp if timestamp != nil

    mumble_write(message)
  end

  def send_query_users ids, names
    message = MumbleProto::QueryUsers.new
    message.ids = ids
    message.names = names

    mumble_write(message)
  end

  def send_user_state session, channel_id
    message = MumbleProto::UserState.new
    message.session = session
    message.actor = session
    message.channel_id = channel_id

    mumble_write(message)
  end

  def send_user_remove session, reason, ban
    message = MumbleProto::UserRemove.new
    message.session = session
    message.reason = reason
    message.ban = ban

    mumble_write(message)
  end

  def send_voice_target id, targets
    message = MumbleProto::VoiceTarget.new
    message.id = id
    message.targets = targets

    mumble_write(message)
  end

protected
  def load_keys
    if (File.exists? 'private_key.pem')
      @key = OpenSSL::PKey::RSA.new File.read 'private_key.pem'
    else 
      @key = OpenSSL::PKey::RSA.new 2048
      open 'private_key.pem', 'w' do |io| io.write @key.to_pem end
      open 'public_key.pem', 'w' do |io| io.write @key.public_key.to_pem end
    end
  end

  def mumble_write(buffer)
    message_string = buffer.serialize_to_string
    message_type = MP_RTYPES[buffer.class]
    type_string = [message_type, message_string.size].pack('nN')
    ret = @ssl_socket.write(type_string + message_string)
    STDERR.puts "--> message type #{buffer.class}, sent #{ret} bytes." if @options[:debug]
  end
 
  def mumble_read()
    type_string = @ssl_socket.read(6)
    return nil if type_string.nil?
 
    type, size = type_string.unpack('nN')
    if type == 1 
        message = MumbleProto::UDPTunnel.new 
        message.packet = @ssl_socket.read(size)
      STDERR.puts "<-- message type #{MP_TYPES[type]} of size #{size}." if @options[:debug]
    else
      return nil unless MP_TYPES.has_key?(type)

      STDERR.puts "<-- message type #{MP_TYPES[type]} of size #{size}." if @options[:debug]
      message_string = @ssl_socket.read(size)
 
      return nil if message_string.nil?
      message = MP_TYPES[type].new.parse_from_string(message_string)
    end
    #STDERR.puts message.inspect if @options[:debug]
    return message
  end

  def listen
    while @connected do
      message = mumble_read()
      break if message.nil?
      message_handler(message)
    end
    @connected = false
  end

  # default message handler, override in derived class
  def message_handler(message)
   puts "called handler #{message.class}"
  end

  # without a ping the connections gets dropped after 30 secs
  def pinger
    while @connected do
      sleep 10
      send_ping
    end
  end

  def udp_pinger
    while @connected do
      sleep 1
      send_udp_ping
    end
  end

  def send_udp_ping    
#    @udp_scket.send("hello")
  end
end

