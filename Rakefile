begin
  require 'voxpupuli/test/rake'
rescue LoadError
  # only available if gem group :test is installed
end

begin
  require 'voxpupuli/acceptance/rake'
rescue LoadError
  # only available if gem group :system_tests is installed
end

begin
  require 'voxpupuli/release/rake_tasks'
rescue LoadError
  # only available if gem group :release is installed
else
  GCGConfig.user    = 'voxpupuli'
  GCGConfig.project = 'puppet-victorialogs'
end

desc 'Generate REFERENCE.md via puppet-strings'
task :reference do
  sh 'puppet strings generate --format markdown --out REFERENCE.md'
end
