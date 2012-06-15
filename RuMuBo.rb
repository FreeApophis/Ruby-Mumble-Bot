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
require File.expand_path "../config", __FILE__

op = OptionParser.new do |opts|
  opts.banner = "Usage: mbot.rb [OPTIONS] \n\n"
  opts.on("-d", "--debug", "Debugging.") do
    $options[:debug] = true
  end
  opts.on("-h", "--help", "This Help") do |h|
    puts opts.help();
    exit 0;
  end
  opts.separator("")
  opts.separator("Example:")
  opts.separator("  RuMuBo.rb")
  opts.separator("")
  opts.separator("Configure:")
  opts.separator("  edit your config.rb")
  opts.separator("")
end

op.parse!

if (ARGV.length < 0)
  puts "Parameter 'Server' Missing:"
  puts op.help
  exit 0
end

client = Client.new $options

trap("INT") do
  client.exit_by_user
  exit 0
end

Thread.abort_on_exception = true

client.run $servers



