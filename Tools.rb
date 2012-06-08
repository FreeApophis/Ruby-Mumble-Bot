#!/usr/bin/ruby
# RubyMumbleBot
# ----------------------

require File.expand_path "../MessageTypes", __FILE__

class Tools
  def self.platform
    if RUBY_PLATFORM =~ /win32/
      return "Windows"
    elsif RUBY_PLATFORM =~ /linux/
      return "Linux"
    elsif RUBY_PLATFORM =~ /darwin/
      return "MacOS X"
    elsif RUBY_PLATFORM =~ /freebsd/
      return "FreeBSD"
    else
      return "unknown"
    end
  end

  def self.decode_type_target byte
    type = (byte & 0xE0) >> 5
    target = (byte & 0x1F) 
    return  { :type => type, :target => target }
  end

  def self.decode_varint packet, index
    p1 = packet[index]
    if (p1 & 0x80) == 0x00
      new_index = index
      result = p1 & 0x7F
    elsif (p1 & 0xC0) == 0x80
      new_index = index + 1
      result = (p1 & 0x3F) << 8 | packet[new_index]
    elsif (p1 & 0xF0) == 0xF0
      case (p1 & 0xFC)
        when 0xF0
          new_index = index + 4
          result = p1 << 24 | packet[index + 1] << 16 | packet[index + 2] << 8 | packet[index + 3]
        when 0xF4
          new_index = index + 8
          result = p1 << 56 | packet[index + 1] << 48 | packet[index + 2] << 40 | packet[nindex + 3] << 32 | 
                   packet[index + 4] << 24 | packet[index + 5] << 16 | packet[index + 6] << 8 | packet[index + 7]
        when 0xF8
          temp = decode_varint packet, index + 1
          result = ~temp[:result]
          new_index = temp[:new_index]
        when 0xFC
          new_index = index + 1
          result = p1 & 0x03
          result = ~result
        else
          raise "Decode Varint failed"
          new_index = 0
      end
    elsif (p1 & 0xF0) == 0xE0
      new_index = index + 4
      result =(p1 & 0x0F) << 24 |  packet[index + 1] << 16 | packet[index + 2] << 8 | packet[index + 3]
    elsif (p1 & 0xE0) == 0xC0
      new_index = index + 3
      result = (p1 & 0x1F) << 16 |  packet[index + 1] << 8 | packet[index + 2]
    end
    return { :result => result, :index => index, :new_index => new_index + 1}
  end

  def self.encode_varint value
    #TODO: negative numbers
    packet = []
    #quint64 i = value

    if (value < 0x80)
      # Need top bit clear
      packet <<  value
    elsif (value < 0x4000)
      # Need top two bits clear
      packet << ((value >> 8) | 0x80)
      packet << (value & 0xFF)
    elsif (value < 0x200000)
      # Need top three bits clear
      packet << ((value >> 16) | 0xC0)
      packet << ((value >> 8) & 0xFF)
      packet << (value & 0xFF)
    elsif (value < 0x10000000)
      # Need top four bits clear
      packet << ((value >> 24) | 0xE0)
      packet << ((value >> 16) & 0xFF)
      packet << ((value >> 8) & 0xFF)
      packet << (value & 0xFF);
    elsif (value < 0x100000000)
      # It's a full 32-bit integer.
      packet << (0xF0)
      packet << ((value >> 24) & 0xFF)
      packet << ((value >> 16) & 0xFF)
      packet << ((value >> 8) & 0xFF)
      packet << (value & 0xFF)
    else
      # It's a 64-bit value.
      packet << (0xF4)
      packet << ((value >> 56) & 0xFF)
      packet << ((value >> 48) & 0xFF)
      packet << ((value >> 40) & 0xFF)
      packet << ((value >> 32) & 0xFF)
      packet << ((value >> 24) & 0xFF)
      packet << ((value >> 16) & 0xFF)
      packet << ((value >> 8) & 0xFF)
      packet << (value & 0xFF)
    end
    return packet.pack('c*')
  end
end
