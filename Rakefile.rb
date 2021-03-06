# -*- coding: utf-8 -*-
# 
# This file is part of Papyrus.
# 
# Papyrus is a RDoc plugin for generating PDF files.
# Copyright © 2011  Pegasus Alpha
# 
# Papyrus is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# 
# Papyrus is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with Papyrus; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

gem "rdoc", ">= 3"
require "rake"
require "rake/clean"
require "rake/testtask"
require "rdoc/task"
require "rubygems/package_task"
require_relative "lib/rdoc/generator/papyrus"

#The project’s title as it appears in the docs.
PROJECT_TITLE = "Papyrus--LaTeX-PDF generator for RDoc"
#The project’s name, to be used for the gem name
PROJECT_NAME = "papyrus"
#A one-line summary of the project, used for the gem summary
PROJECT_SUMMARY = "PDF generator plugin for RDoc, based on LaTeX"
#A full description of the whole thing
PROJECT_DESC =<<DESC
Papyrus is a PDF generator plugin for RDoc based on LaTeX. It
allows you to turn your project's documentation into a nice PDF file
instead of the usual HTML output.
DESC

#All core files that belong to the project and shall be
#included in the gem
PROJECT_FILES = [
                 Dir["data/**/*"],
                 Dir["lib/**/*.rb"],
                 Dir["**/**/*.rdoc"],
                 Dir["**/**/*.txt"],
                 "VERSION.txt",
                 "COPYING"
                 ].flatten

#External dependencies RubyGems cannot fulfill
PROJECT_REQUIREMENTS = [
                        "(pdf)LaTeX2e: For the actual PDF generation."
                        ]

#List of projects to document in the :document_test task
TEST_PROJECTS = %w[rails railties activerecord nokogiri coderay]
TEST_PROJECTS_DIR = "test/gems"

#The gem specification
GEMSPEC = Gem::Specification.new do |spec|
  spec.name = PROJECT_NAME
  spec.summary = PROJECT_SUMMARY
  spec.description = PROJECT_DESC
  spec.version = RDoc::Generator::Papyrus::VERSION.gsub("-", ".")
  spec.author = "Marvin Gülker"
  spec.email = "m-guelker@pegasus-alpha.eu"
  spec.homepage = "http://redmine.pegasus-alpha.eu/projects/papyrus"
  spec.platform = Gem::Platform::RUBY
  spec.required_ruby_version = ">= 1.9"
  spec.add_dependency("rdoc", ">= 3.9.1")
  spec.add_development_dependency("hanna-nouveau")
  spec.requirements = PROJECT_REQUIREMENTS
  spec.files = PROJECT_FILES
  spec.has_rdoc = true
  spec.extra_rdoc_files = %w[README.rdoc COPYING]
  spec.rdoc_options << "-t" << PROJECT_TITLE << "-m" << "README.rdoc"
end

Gem::PackageTask.new(GEMSPEC).define

#Temporary directory used for generating the HTML
#documentation.
TMP_DOC_DIR = "tmp"

CLEAN.include(TMP_DOC_DIR, TEST_PROJECTS_DIR)
ENV["RDOCOPT"] = nil #Needed to override my "-f hanna" default

desc "Generate RDoc documentation in HTML format."
task :rdoc_html do
  #This is a workaround the situation that defining
  #multiple RDoc::Tasks in a Rakefile doesn't work
  #correctly--if calling one of the task, *all* get executed.
  rm_rf TMP_DOC_DIR if File.directory?(TMP_DOC_DIR)
  mkdir TMP_DOC_DIR
  cd TMP_DOC_DIR
  File.open("Rakefile", "w") do |f|
    f.write(<<-EOF)
require "rake"
gem "rdoc", ">= 3"
require "rdoc/task"
RDoc::Task.new do |r|
  r.generator = "hanna"
  r.rdoc_files.include("../lib/**/*.rb", "../**/**/*.rdoc", "..**/**/*.txt", "../COPYING")
  r.title = "#{PROJECT_TITLE}"
  r.main = "README.rdoc"
  r.rdoc_dir = "../doc"
end
    EOF
  end
  sh "rake rdoc"
  cd ".."
end

desc "Rebuild the HTML docs."
task :rerdoc_html => [:clobber_rdoc, :rdoc_html]

RDoc::Task.new do |r|
  r.generator = "papyrus"
  r.rdoc_files.include("lib/**/*.rb", "**/**/*.rdoc", "**/**/*.txt", "COPYING")
  r.title = PROJECT_TITLE
  r.main = "README.rdoc"
  r.rdoc_dir = "doc"
end

Rake::TestTask.new do |t|
  t.test_files = Dir["test/test_*.rb"]
  t.verbose = true
end

task :rdoc_set_debug do
  ENV["RDOCOPT"] = "--debug"
end

desc "Runs the PDF generation in debug mode."
task :rdoc_debug => [:clobber_rdoc, :rdoc_set_debug, :rdoc]

desc "Documents some bigger projects with papyrus."
task :document_test do
  prev_dir = Dir.pwd
  mkdir_p TEST_PROJECTS_DIR
  cd TEST_PROJECTS_DIR
  
  TEST_PROJECTS.each do |gemname|
    recent_version = `gem list #{gemname} -r`.lines.first.match(/\((.*?)(?:\)| )/)[1]
    full_name = "#{gemname}-#{recent_version}"
    puts "Documenting #{full_name}..."
    
    sh "gem fetch #{gemname}"
    sh "gem unpack #{full_name}.gem"
    cd full_name

    main_page = nil
    %w[README README.txt README.rdoc].each{|f| main_page = f if File.file?(f)}
    args = %w[-f papyrus -o papyrus-doc --debug]
    args += %w[-m] + [main_page] if main_page
    args += %w[lib ext] + Dir["*.rdoc"]
    rdoc = RDoc::RDoc.new
    puts "rdoc #{args.join(' ')}"
    rdoc.document(args)

    cd ".."
  end
  cd prev_dir
end
