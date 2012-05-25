#!/usr/bin/ruby
# RubyMumbleBot
# ----------------------

class Channel
  attr_reader :name
  attr_reader :subchannels, :root_channel, :channel_id
  attr_reader :user
  
  def initialize channel_info, root_channel, channels
    @channels = channels
    @channel_id = channel_info.channel_id
    @root_channel = root_channel
    @subchannels = []
    @localusers = []

    if channel_info.has_field? :parent
      @parent_channel = @channels[channel_info.parent]
      @parent_channel.add_subchannel self
    end
    @name = channel_info.name
    @channels[channel_info.channel_id] = self
  end

  def print_tree (level = 0)
    puts ("  "  * level) + "C " + @name + "(#{@channel_id})"
    @subchannels.each { |channel| channel.print_tree(level + 1) }
    @localusers.each { |user| user.print(level + 1) }
  end

  def update channel_info
  end

  def add_localuser user
    @localusers << user
  end

  def remove_localuser user
    @localusers.delete user
  end

protected
  def add_subchannel subchannel
    @subchannels << subchannel
  end
end
