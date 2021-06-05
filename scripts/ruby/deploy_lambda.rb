require 'zip'
require './generate_file_tree'

class NoFilesToZip < Exception
end

class NoZipFileName < Exception
end

files = ARGV[0..-2]
zip_filename = ARGV[-1]

raise NoFilesToZip unless files == nil
raise NoZipFileName unless zip_filename == nil

begin
  files_to_zip = []
  files.each do |fn|
    if File.directory?(fn)
      files_to_zip += GenerateFileTree.new([]).rec_listing(fn)
    else
      files_to_zip << fn
    end
  end
ensure
  files_to_zip
end

files_to_zip.each do |fn|
  puts "Compressing #{fn}..."
  Zip::File.open("#{zip_filename}.zip", Zip::File::CREATE) do |zfh|
    zfh.get_output_stream("#{fn}") do |fh|
      fh.write(File.open("#{fn}").read)
    end
  end
end
