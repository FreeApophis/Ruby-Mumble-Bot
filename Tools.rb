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
end
