# Generate a list of valid files to be transferred
require 'json'

class GenerateFileTree
  # This class will generate a file tree consisting of all the files in the 
  # given filepath and its subdirectories. It takes an optional arguments 
  # exclude_paths that can be used to filter the files. It takes an array of 
  # Ruby compatible regex filters

  attr_reader :file_list, :exclude_paths

  def initialize(path, exclude_paths)
    @exclude_paths = exclude_paths
    @file_list = []
  end

  def exclude?(filepath)
    flag = false
    @exclude_paths.each do |excl|
      # If any of the pattern matches the file name, set flag to 1
      flag = true unless /#{excl}/.match(filepath) == nil 
      break if flag
    end
    flag
  end

  def rec_listing(local_path="")

    # Go through each entity in current directory
    Dir.open(local_path).children.each do |child|
      filepath = "#{local_path}/#{child}"
      rec_listing(filepath) if File.directory?(filepath)
      @file_list << filepath if (!File.directory?(filepath) and !exclude?(filepath))
    end
    @file_list
  rescue  Errno::ENOTDIR => e
    puts "#{local_path} is not a directory. Returning the same path", ""
    # If the given path is not a directory but a file, append it to the list of 
    # files provided
    @file_list << local_path unless exclude?(local_path)
    @file_list
  rescue Errno::ENOENT => e
    puts e.class, e.message, "Path \"#{local_path}\" doesn't exist", ""
  rescue Exception => e
    puts e.class, e.message, e.backtrace, ""
    raise
  ensure
    # Ensure that the return value is atleast the same list that came in
    @file_list
  end

  private :exclude?
end
