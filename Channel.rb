#!/usr/bin/ruby
# RubyMumbleBot
# ----------------------

class Channel
  attr_reader :name
  attr_reader :subchannels, :root_channel, :channel_id
  attr_reader :localusers
  
  def initialize channel_info, root_channel, channels
    @channels = channels
    @channel_id = channel_info.channel_id
    @root_channel = root_channel
    @subchannels = []
    @localusers = []

    @channels[channel_info.channel_id] = self
    if channel_info.has_field? :parent
      @parent_channel = @channels[channel_info.parent]
      @parent_channel.add_subchannel self
    end
    @name = channel_info.name
  end

  def is_root
    return @channel_id == @parent_channel.channel_id
  end

  def tree (level = 0)
    result = ("  "  * level) + "C " + @name + "(#{@channel_id})\n"
    @subchannels.each { |channel| result += channel.tree(level + 1) }
    @localusers.each { |user| result += user.tree(level + 1) }
    return result
  end

  def path
    if @parent_channel
      return @parent_channel.path() + "/" + @name
    else
      return @name
    end
  end

  def update channel_info
  end

  def add_localuser user
    @localusers << user
  end

  def remove_localuser user
    @localusers.delete user
  end

  def inspect
    return name
  end

protected
  def add_subchannel subchannel
    @subchannels << subchannel
  end
end
