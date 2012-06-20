#!/usr/bin/ruby
# RubyMumbleBot
# ----------------------

class User
  attr_reader :name, :session, :user_id, :comment, :channel
  attr_reader :self_deaf, :self_mute, :deaf, :mute, :suppress
  attr_reader :priority_speaker, :recording

  def initialize client, message
    @name = message.name
    @channel_id = message.channel_id
    @channel = client.channels[@channel_id]
    @channel.add_localuser self
    @users = client.users
    @users[message.session] = self
    @session = message.session
    @user_id = nil
    @user_id = message.user_id if message.has_field? :user_id
  end

  def update(client, message)
    if (message.has_field? :channel_id) && (message.channel_id != @channel_id)
      @channel.remove_localuser self
      @channel_id = message.channel_id
      @channel = client.channels[@channel_id]
      @channel.add_localuser self
    end

    if message.has_field? :mute
      @mute = message.mute
    end

    if message.has_field? :deaf
      @deaf = message.deaf
    end

    if message.has_field? :suppress
      @suppress = message.suppress
    end

    if message.has_field? :self_mute
      @self_mute = message.self_mute
    end

    if message.has_field? :self_deaf
      @self_deaf = message.self_deaf
    end

    if message.has_field? :texture
      @texture = message.texture
    end

    if (message.has_field? :texture_hash) and  (@texture_hash != message.texture_hash)
      @texture_hash = message.texture_hash
      client.send_request_blob @session, nil, nil
    end

    if message.has_field? :comment
      @comment = message.comment
    end

    if (message.has_field? :comment_hash) and (@comment_hash != message.comment_hash)
      @comment_hash = message.comment_hash
      client.send_request_blob nil, @session, nil
    end

    if message.has_field? :hash
      @certificate_hash = message.hash
    end

    if message.has_field? :priority_speaker
      @priority_speaker = message.priority_speaker
    end

    if message.has_field? :recording
      @recording = message.recording
    end

    if message.has_field? :user_id
      @user_id = message.user_id
    end
  end

  def remove
      @channel.remove_localuser self
      @users.delete @session
  end

  def tree(level = 0)
    return ("  "  * level) + "U " + @name + " (#{@session})\n"
  end
end

