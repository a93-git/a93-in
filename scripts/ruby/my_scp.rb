fh = File.open(".scpconfig")

fh.each_line do |file|
  puts file
  puts File.directory?(file)
end

