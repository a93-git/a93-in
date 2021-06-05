#!/usr/bin/ruby
require "uri"

request_body = URI.decode_www_form(gets.chomp).to_h

request_body.each do |k, v|
  File.open(Time.now.to_s.gsub(" ", "_").gsub(":", "-").gsub("+", ""), 
            File::APPEND | File::CREAT | File::WRONLY, 
            0644) do |fh|
    fh.write("#{k}:\n#{v}\n\n")
  end
end

puts "Content-Type: text/html\n\n"
puts "Hello, World!"
