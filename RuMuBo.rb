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

require File.expand_path "../Client", __FILE__

options = { 
  :version => "RuMuBo 0.4",
  :debug => false,
  :username => "RuMuBo", 
  :country_code => "CH",
  :organisation => "Apophis.ch",
  :organisation_unit => "Software",
  :mail_address => "apophis@apophis.ch"
}

op = OptionParser.new do |opts|
  opts.banner = "Usage: mbot.rb SERVER[:PORT][/channel] [OPTIONS] \n\n"
  opts.on("-c CHAN", "--channel CHAN", "Switch to Channel.") do  |chan|
    options[:channel] = chan
  end
  opts.on("-d", "--debug", "Debugging.") do
    options[:debug] = true
  end
  opts.on("-h", "--help", "This Help") do |h|
    puts opts.help();
    exit 0;
  end
  opts.on("-u", "--username", "Set a username") do |username|
    options[:username] = username
  end

  opts.separator("")
  opts.separator("Example:")
  opts.separator("  RuMuBo.rb")
  opts.separator("")
end

op.parse!

if (ARGV.length < 0)
  puts "Parameter 'Server' Missing:"
  puts op.help
  exit 0
end

client = Client.new options

trap("INT") do
  client.exit_by_user
  exit 0
end

Thread.abort_on_exception = true

servers = []
servers << { :host => "apophis.ch", :port => 64738, :channel => "International Bridge" }
servers << { :host => "talk.piratenpartei.ch", :port => 64738, :channel => "International Bridge" }

client.run servers


