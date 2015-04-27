require "rubygems"

spec = Gem::Specification.new do |s|
  s.name = %q{ncal2gcal}
  s.version = "0.1.6"
  s.authors = ["Elias Kugler"]
  s.email = %q{groesser3@gmail.com}
  s.files =   Dir["lib/**/*"] + Dir["bin/**/*"] + Dir["*.rb"] + ["MIT-LICENSE","ncal2gcal.gemspec"]
  s.platform    = Gem::Platform::RUBY
  s.has_rdoc = true
  s.extra_rdoc_files = ["README.rdoc", "CHANGELOG.rdoc"]
  s.require_paths = ["lib"]
  s.summary = %q{Sync your Lotus Notes calendar with your Google calendar}
  s.description = %q{This lib/tool syncs your IBM Lotus Notes calendar with your (private) Google calendar. The synchronisation is only one-way: Lotus Notes events are pushed to your Google Calendar. All types of events (including recurring events like anniversaries) are supported.}
  s.files.reject! { |fn| fn.include? "CVS" }
  s.require_path = "lib"
  s.default_executable = %q{ncal2gcal}
  s.executables = ["ncal2gcal"]
  s.homepage = %q{http://rubyforge.org/projects/ncal2gcal/}
  s.rubyforge_project = %q{ncal2gcal}
  s.add_dependency("dm-core", ">= 0.10.0")
  s.add_dependency("do_sqlite3", ">= 0.10.0")
  s.add_dependency("gcal4ruby", ">=0.3.1")
  s.add_dependency("log4r", ">=1.0.5")

end


if $0 == __FILE__
   Gem.manage_gems
   Gem::Builder.new(spec).build
end
