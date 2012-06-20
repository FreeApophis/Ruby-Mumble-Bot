class MessageHandler
  def initialize client
    client.register_text_handler "!find", method(:on_find)
    client.register_text_handler "!goto", method(:on_goto)
    client.register_text_handler "!test", method(:test)
  end

private
  def on_find client, message
    text = message.message

    nick = text[6..-1]
    user = client.find_user nick
    if user
      client.send_user_message message.actor, "User '#{user.name}' is in Channel '#{user.channel.path}'"
    else
      client.send_user_message message.actor, "There is no user '#{nick}' on the Server"
    end
  end

  def on_goto client, message
    text = message.message

    nick = text[6..-1]
    target = client.find_user nick
    source = client.find_user message.actor
    client.move_user source, target.channel
  end

  def test client, message
    client.channels.each do |id, ch|
      client.send_acl id
    end
  end
end
