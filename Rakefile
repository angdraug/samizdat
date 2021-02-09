require "rake"

task :default => :test

task :test do
  sh %{#{FileUtils::RUBY} -I. -Ilib test/ts_samizdat.rb}
end
