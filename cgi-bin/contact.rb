#!/usr/bin/ruby
require "uri"
require "uuid"
require "./dynamohandler"

request_body = URI.decode_www_form(gets.chomp).to_h
handler = DynamoHandler.new("us-east-1", "A93")
uuid = UUID.new

message = {} 
request_body.each do |k, v|
  message[k] = v
end

message["id"] = uuid.generate
response = handler.put_item(message)

puts "Location: https://a93.in\n\n"
