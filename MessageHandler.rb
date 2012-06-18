class MessageHandler
  def initialize client
    client.register_text_handler "!find", method(:on_find)
    client.register_text_handler "!goto", method(:on_goto)
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
    user = client.find_user nick

    client.move_user
  end
end
