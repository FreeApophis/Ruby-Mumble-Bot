#!/usr/bin/ruby
# RubyMumbleBot
# ----------------------

class User
  attr_reader :name, :session, :user_id, :comment, :channel
  attr_reader :self_deaf, :self_mute, :deaf, :mute, :suppress
  attr_reader :priority_speaker, :recording

  def initialize user_info, users, channels
    @name = user_info.name
    @channel_id = user_info.channel_id
    @channel = channels[@channel_id]
    @channel.add_localuser self
    @users = users
    @users[user_info.session] = self
    @session = user_info.session
  end

  def update(user_info, channels)
    if (user_info.has_field? :channel_id) && (user_info.channel_id != @channel_id)
      @channel.remove_localuser self
      @channel_id = user_info.channel_id
      @channel = channels[@channel_id]
      @channel.add_localuser self
    end

    if user_info.has_field? :deaf
      @deaf = user_info.deaf
    end

    if user_info.has_field? :mute
      @mute = user_info.mute
    end

    if user_info.has_field? :self_deaf
      @self_deaf = user_info.self_deaf
    end

    if user_info.has_field? :self_mute
      @self_mute = user_info.self_mute
    end

    if user_info.has_field? :suppress
      @suppress = user_info.suppress
    end

    if user_info.has_field? :priority_speaker
      @priority_speaker = user_info.priority_speaker
    end

    if user_info.has_field? :recording
      @recording = user_info.recording
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

