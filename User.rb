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
puts "DANGER"
      @channel.remove_localuser self
      @channel_id = user_info.channel_id
      @channel = channels[@channel_id]
      @channel.add_localuser self

      @channel.root_channel.print_tree
    end
  end

  def print(level)
    puts ("  "  * level) + "U " + @name
  end
end

