require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'

desc 'Default: run unit tests.'
task :default => :test

desc 'Test the report `plugin.'
Rake::TestTask.new(:test) do |t|
  t.libs << 'lib'
  t.pattern = 'test/**/*_test.rb'
  t.verbose = true
end

desc 'Generate documentation for the report plugin.'
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'Report'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

require 'fileutils'
desc "Remove unnecessary files in the test/rails_root directory"
task :prune_rails_root do
  rails_root = File.join(File.dirname(__FILE__), *%w[test rails_root])
  def nuke(path_string)
    list = Dir.glob(path_string)
    puts "Deleting #{list.length} item(s) from #{path_string}"
    FileUtils.rm_rf list
  end
  nuke rails_root + '/log/*.log'
  nuke rails_root + '/test'
  nuke rails_root + '/public'
end
