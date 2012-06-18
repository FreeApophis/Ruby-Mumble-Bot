#!/usr/bin/ruby
# RubyMumbleBot
# ----------------------

require 'socket'
require 'openssl'
require 'fileutils'

require File.expand_path "../Mumble.pb", __FILE__
require File.expand_path "../MessageTypes", __FILE__
require File.expand_path "../Tools", __FILE__

class MumbleConnection
  def initialize server, port, username, options
    @server = server
    @port = port
    @username = username
    @options = options
    unless File.exists?(@username)
      FileUtils.mkdir @username
    end

    # Version 1.2.3
    @mumble_version = (1 << 16) + (2 << 8) + 3 
    @connected = false
    ssl_key_setup
  end

  # Connection State
  def connected?
    return @connected
  end

  def connect
    unless @username
      raise "We cannot connect without a username"
    end

    begin
      socket = TCPSocket.new(@server, @port)

      #requires TLS 1 / SSL fails
      ssl_context = OpenSSL::SSL::SSLContext.new(:TLSv1)
      ssl_context.verify_mode = OpenSSL::SSL::VERIFY_NONE
      ssl_context.key = @key
      ssl_context.cert = @cert

      @ssl_socket = OpenSSL::SSL::SSLSocket.new(socket, ssl_context)
      @ssl_socket.sync_close = true
      @ssl_socket.connect

      $stderr.print "SSLSocket connected.\n" if @options[:debug]
      $stderr.print @ssl_socket.peer_cert.to_text, "\n" if @options[:debug]
    
      @connected = true

      @udp_socket = UDPSocket.new
      @udp_socket.connect(@server, @port)

      Thread.new { listen }
      Thread.new { pinger }
      Thread.new { udp_pinger }
    rescue
      puts $! 
      puts "Connection failed. EXIT" 
      exit
    end
  end

  def disconnect
    @connected = false
    @ssl_socket.close
  end

  # Lowlevel Send API
  def send_version client_version
    message = MumbleProto::Version.new
    message.release = client_version
    message.version =  @mumble_version
    message.os = Tools.platform
    message.os_version = RUBY_PLATFORM

    mumble_write(message)
  end

  def send_udp_tunnel packet
    message = MumbleProto::UDPTunnel.new
    message.packet = packet

    mumble_write(message)
  end

  def send_authenticate username
    message = MumbleProto::Authenticate.new
    message.username = username
    message.celt_versions << -2147483637
    message.celt_versions << -2147483632

    mumble_write(message)
  end

  def send_ping 
    message = MumbleProto::Ping.new
    message.timestamp = Time.now.to_i

    @last_ping = { :ts => message.timestamp, :ping => Time.now }

    mumble_write(message)
  end

  def send_reject
    raise("server only message")
  end

  def send_server_config
  end

  def send_server_sync
    raise("server only message")
  end

  def send_channel_remove channel_id
    message = MumbleProto::ChannelRemove.new
    message.channel_id = channel_id

    mumble_write(message)
  end

  def send_channel_state
  end

  def send_user_remove session, reason, ban
    message = MumbleProto::UserRemove.new
    message.session = session
    message.reason = reason
    message.ban = ban

    mumble_write(message)
  end

  def send_user_state session, channel_id, self_mute, self_deaf
    message = MumbleProto::UserState.new
    message.session = session
    message.actor = session
    message.channel_id = channel_id if channel_id
    message.self_mute = self_mute if self_mute != nil
    message.self_deaf = self_deaf if self_deaf != nil

    mumble_write(message)
  end

  def send_ban_list bans, query
    message = MumbleProto::BanListNew.new
    message.bans = bans if bans != nil
    message.query = query

    mumble_write(message)
  end

  def send_text_message actor, message_text, session = nil, channel_id = nil, tree_id = nil
    message = MumbleProto::TextMessage.new
    message.actor = actor
    message.session << session if session
    message.channel_id << channel_id if channel_id
    message.tree_id << tree_id if tree_id
    message.message = message_text

    mumble_write(message)
  end

  def send_permission_denied
    message = MumbleProto::PermissionDenied.new

    raise("server only message")
  end

  def send_acl
  end

  def send_query_users ids, names
    message = MumbleProto::QueryUsers.new
    message.ids = ids
    message.names = names

    mumble_write(message)
  end

  def send_crypt_setup
  end

  def send_context_action_modify
  end

  def send_context_action
  end

  def send_user_list
    message = MumbleProto::UserList.new

    mumble_write(message)
  end

  def send_voice_target id, targets
    message = MumbleProto::VoiceTarget.new
    message.id = id
    message.targets = targets

    mumble_write(message)
  end

  def send_permission_query channel_id, permissions, flush
    message = MumbleProto::PermissionQuery.new
    message.channel_id = channel_id if channel_id
    message.permission = permissions if permissions
    message.flush = flush if flush != nil

    mumble_write(message)  
  end

  def send_codec_version
  end

  def send_user_stats session
    message = MumbleProto::UserStats.new
    message.session = session

    mumble_write(message)  
  end

  def suggest_config
  end

  def send_request_blob session_texture, session_comment, channel_description
    message = MumbleProto::RequestBlob.new
    message.session_texture = session_texture
    message.session_comment = session_comment
    message.channel_description = channel_description

    mumble_write(message)
  end

protected
  # SSL Setup
  def ssl_key_setup
    if (File.exists? File.join(@username, 'private_key.pem'))
      @key = OpenSSL::PKey::RSA.new File.read File.join(@username, 'private_key.pem')
    else 
      @key = OpenSSL::PKey::RSA.new 2048
      open File.join(@username, 'private_key.pem'), 'w' do |io| io.write @key.to_pem end
      open File.join(@username, 'public_key.pem'), 'w' do |io| io.write @key.public_key.to_pem end
    end

    if (File.exists? File.join(@username, 'cert.pem'))
      @cert = OpenSSL::X509::Certificate.new File.read(File.join(@username, 'cert.pem'))
    else 
      subject = "/C=#{@options[:country_code]}/O=#{@options[:organisation]}/OU=#{@options[:organisation_unit]}/CN=#{@username}"

      @cert = OpenSSL::X509::Certificate.new
      @cert.subject = @cert.issuer = OpenSSL::X509::Name.parse(subject)
      @cert.not_before = Time.now
      @cert.not_after = Time.now + 365 * 24 * 60 * 60 * 5
      @cert.public_key = @key.public_key
      @cert.serial = rand(65535) + 1
      @cert.version = 2

      ef = OpenSSL::X509::ExtensionFactory.new
      ef.subject_certificate = @cert
      ef.issuer_certificate = @cert

      @cert.add_extension(ef.create_extension("basicConstraints","CA:TRUE",true))
      @cert.add_extension(ef.create_extension("keyUsage","keyCertSign, cRLSign", true))
      @cert.add_extension(ef.create_extension("subjectKeyIdentifier","hash",false))
      @cert.add_extension(ef.create_extension("authorityKeyIdentifier","keyid:always",false))
      
      @cert.sign(@key, OpenSSL::Digest::SHA256.new)

      open File.join(@username, 'cert.pem'), 'w' do |io| io.write @cert.to_pem end
    end
  end

  # No direct access to the socket (private)
  def mumble_write(buffer)
    message_string = nil
    if buffer.is_a? MumbleProto::UDPTunnel
      message_string = buffer.packet
    else 
      message_string = buffer.serialize_to_string
    end
    message_type = MP_RTYPES[buffer.class]
    type_string = [message_type, message_string.size].pack('nN')

    begin
      ret = @ssl_socket.write(type_string + message_string)
      $stderr.puts "--> message type #{buffer.class}, sent #{ret} bytes." if @options[:debug]
    rescue IOError => e
    end
  end
 
  def mumble_read()
    type_string = @ssl_socket.read(6)
    return nil if type_string.nil?
 
    type, size = type_string.unpack('nN')
    if type == 1 
      message = MumbleProto::UDPTunnel.new 
      message.packet = @ssl_socket.read(size)
      $stderr.puts "<-- message type #{MP_TYPES[type]} of size #{size}." if @options[:debug]
    else
      return nil unless MP_TYPES.has_key?(type)

      $stderr.puts "<-- message type #{MP_TYPES[type]} of size #{size}." if @options[:debug]
      message_string = @ssl_socket.read(size)
 
      return nil if message_string.nil?
      message = MP_TYPES[type].new.parse_from_string(message_string)
    end
    #$stderr.puts message.inspect if @options[:debug]
    return message
  end

  # Main Protocol Thread
  def listen
    while @connected do
      begin
        message = mumble_read()
        break if message.nil?
        message_handler(message)
      rescue IOError => e
      end
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

