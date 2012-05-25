Ruby-Mumble-Bot
===============

Ruby Interface to the Mumble Client Protocol

What do you need?
=================

* Install ruby and rubygems
* Install rubygem ruby_protobuf

Running RuMuBo
==============

* ruby RuMuBo.rb Server:Port [OPTIONS]

Development
===========

Q: Do I need the Mumble.proto file?
A: No, The Mumble.pb.rb has been generated for you, but you can compile it yourself with the ruby protobuf compiler. (command: rprotoc)

Q: Whats the difference between MumbleConnection and MumbleClient.
A: The Lowlevel interfaces are done in MumbleConnection, these are basically the protocol messages with all possible paramteres,
   MumbleClent offers a High-Level API on MumbleClient, which concentrates rather on the task to be done than on how.
