require 'zip'
require './generate_file_tree'

class ZipFilesRec
  attr_reader :zip_filename

  def initialize(*files, zip_filename)
    @files = files
    @zip_filename = "#{zip_filename}.zip"
    @files_to_zip = []
  end

  def get_files_to_zip
    @files.each do |fn|
      if File.directory?(fn)
        @files_to_zip += GenerateFileTree.new([]).rec_listing(fn)
      else
        @files_to_zip << fn
      end
    end
  ensure
    @files_to_zip
  end

  def zip
    get_files_to_zip.each do |fn|
      puts "Compressing #{fn}..."
      Zip::File.open("#{@zip_filename}", Zip::File::CREATE) do |zfh|
        zfh.get_output_stream("#{fn}") do |fh|
          fh.write(File.open("#{fn}").read)
        end
      end
    end
  rescue Exception => e
    puts "Error in compressing file"
    raise
  end

  private :get_files_to_zip
end
