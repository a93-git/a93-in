require 'net/scp'

# Generate the templates into HTML files
puts "Generating the static files from templates..."
`ruby scripts/ruby/generate_post_link.rb projects/ templates/projects.html.erb projects.html`
`ruby scripts/ruby/generate_post_link.rb posts/ templates/index.html.erb index.html`
puts "Static file generation complete..."

puts ""

# scp files from local to remote system
puts "Copying files to the webserver"
fh = File.open(".scpconfig")

transfer = {}

Net::SCP.start("a93", "abhishek") do |scp|
  fh.each_line do |line|
    puts line
    path = line.split
    scp.upload(path[0], path[1], :recursive => true) do |ch, name, sent, total|
      transfer[name] = "#{sent}/#{total}"
      print "#{name}: #{sent}/#{total}                 "
      STDOUT.goto_column(0)
    end
  end
end

STDOUT.erase_line(2)
puts "" 

puts "Transfer complete"
puts "Transfer status by file..."
transfer.each do |k, v|
  puts "#{k}\t\t\t=> #{v}"
end
