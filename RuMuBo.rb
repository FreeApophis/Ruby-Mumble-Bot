#!/usr/bin/ruby
# RubyMumble
# ----------------------
#
# Prerequisites: Ruby, gem ruby_protobuf
#
# inspiration: http://pastebin.com/BRMPENUF


require 'rubygems'
require 'optparse'
require 'pp'
require 'fileutils'
require 'socket'
require 'openssl'

require File.expand_path "../Mumble.pb", __FILE__
require File.expand_path "../MumbleClient", __FILE__


options = { :debug => false }

op = OptionParser.new do |opts|
  opts.banner = "Usage: mbot.rb SERVER[:PORT] [OPTIONS] \n\n"
  opts.on("-c CHAN", "--channel CHAN", "Switch to Channel.") do  |chan|
    options[:chan] = chan
  end
  opts.on("-d", "--debug", "Debugging.") do
    options[:debug] = true
  end
  opts.on("-h", "--help", "This Help") do |h|
    puts opts.help();
    exit 0;
  end

  opts.separator("")
  opts.separator("Example:")
  opts.separator("  RuMuBo.rb")
  opts.separator("")
end

op.parse!

if (ARGV.length == 0)
  puts "Parameter 'Server' Missing:"
  puts op.help
  exit 0
end

server = ARGV[0].split(":")

client = MumbleClient.new(server[0], server.length > 1 ? server[1] : 64738, options)
client.version = "RuMuBo 0.3"
client.username = "RuMuBo"
client.connect

#while client.ready?

trap("INT") do
  puts ""
  puts "Interrupted by user, exit."
  client.debug
  exit
end

while client.connected? do
  sleep 0.2
end
