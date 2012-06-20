#!/usr/bin/ruby
# RubyMumbleBot
# ----------------------

class Channel
  attr_reader :name, :description
  attr_reader :subchannels, :root_channel, :channel_id, :linked_channels, :parent_channel
  attr_reader :localusers
  attr_reader :temporary, :position
  
  def initialize client, message
    @channels = client.channels
    @channel_id = message.channel_id
    @root_channel = client.root_channel
    @subchannels = []
    @localusers = []

    @channels[message.channel_id] = self
    if message.has_field? :parent
      @parent_channel = @channels[message.parent]
      @parent_channel.add_subchannel self
    end
    @name = message.name
  end

  def root?
    return @channel_id == @parent_channel.channel_id
  end

  def ordered_subchannels
    return @subchannels.sort { |ch1, ch2| ch1.position <=> ch2.position }
  end  

  def tree (level = 0)
    result = ("  "  * level) + "C " + @name + "(id:#{@channel_id},pos#{@position})\n"
    ordered_subchannels.each { |channel| result += channel.tree(level + 1) }
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

  def update client, message
    if message.has_field? :temporary
      @temporary = message.temporary
    end

    if message.has_field? :position
      @position = message.position
    end


    if message.has_field? :description
      @description = message.description
    end

    if (message.has_field? :description_hash) and  (@description_hash != message.description_hash)
      @description_hash = message.description_hash
      client.send_request_blob nil, nil, @channel_id
    end
  end

  def remove
    @parent_channel.subchannels.delete self
    @channels.delete @channel_id
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
