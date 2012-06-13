#!/usr/bin/ruby
# RubyMumbleBot
# ----------------------

class User
  attr_reader :name, :session, :channel

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
  end

  def remove
      @channel.remove_localuser self
      @users.delete @session
  end

  def tree(level = 0)
    return ("  "  * level) + "U " + @name + " (#{@session})\n"
  end
end

