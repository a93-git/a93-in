# Generate the templates into HTML files


# scp files from local to remote system
require 'net/scp'

fh = File.open(".scpconfig")

Net::SCP.start("a93", "abhishek") do |scp|
  fh.each_line do |line|
    puts line
    path = line.split
    scp.upload(path[0], path[1], :recursive => true) do |ch, name, sent, total|
      puts "#{name}: #{sent}/#{total}"
    end
  end
end
