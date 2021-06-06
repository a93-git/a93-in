require 'erb'
require 'nokogiri'
require 'json'

CONFIG = JSON.load(File.open(".scpconfig.json"))["development"]
local_root = CONFIG["local_root"]
require "#{local_root}/scripts/ruby/generate_file_tree"

class RenderIndexPage
  def initialize
    @template = ERB.new(File.open("templates/index.html.erb").read)
    @head_partial = File.open("templates/head.html.part").read
    @navbar_partial = File.open("templates/navbar.html.part").read
    @gl = setup_gl
  end

  def render
    @template.result binding
  end

  def setup_gl
    links = []
    GenerateFileTree.new([".html$"]).rec_listing!("html/posts")&.each do |path|
      doc = Nokogiri::HTML(File.open(path))
      links << "<a href=#{path}>#{doc.xpath("//h1").text}</a>"
    end
    links
  end
end

class RenderProjectsPage
  def initialize
    @template = ERB.new(File.open("templates/projects.html.erb").read)
    @head_partial = File.open("templates/head.html.part").read
    @navbar_partial = File.open("templates/navbar.html.part").read
    @gl = setup_gl # gl stands for generated links
  end

  def render
    @template.result binding
  end

  def setup_gl
    links = []
    GenerateFileTree.new([".html$"]).rec_listing!("html/projects")&.each do |path|
      doc = Nokogiri::HTML(File.open(path))
      links << "<a href=#{path}>#{doc.xpath("//h1").text}</a>"
    end
    links
  end
end

class RenderContactPage
  def initialize
    @template = ERB.new(File.open("templates/contact.html.erb").read)
    @head_partial = File.open("templates/head.html.part").read
    @navbar_partial = File.open("templates/navbar.html.part").read
  end

  def render
    @template.result binding
  end
end

class RenderPostsPage
  def initialize(path)
    @template = ERB.new(File.open("templates/posts.html.erb").read)
    @head_partial = File.open("templates/head.html.part").read
    @navbar_partial = File.open("templates/navbar.html.part").read
    @post_body = File.open(path).read
  end

  def render
    @template.result binding
  end
end


puts "Rendering index page"
index_obj = RenderIndexPage.new
File.open("index.html", "w") do |fp|
  fp.write(index_obj.render)
end

puts "Rendering projects page"
projects_obj = RenderProjectsPage.new
File.open("#{local_root}/projects.html", "w") do |fp|
  fp.write(projects_obj.render)
end

puts "Rendering contact page"
contact_obj = RenderContactPage.new
File.open("#{local_root}/contact.html", "w") do |fp|
  fp.write(contact_obj.render)
end

puts "Rendering posts pages"
GenerateFileTree.new([".md$"]).rec_listing("html/posts").each do |fp|
  obj = RenderPostsPage.new(fp).render
  file_path = fp.split("/")[-1] 
  File.open(fp, "w") do |fh|
    fh.write(obj)
  end
end

