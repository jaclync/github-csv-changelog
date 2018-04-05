Gem::Specification.new do |s|
  s.name        = 'github-csv-changelog'
  s.version     = '0.0.0'
  s.date        = '2018-04-05'
  s.summary     = "Parses Github commits and exports to CSV."
  s.description = "Most useful for squash merge commits on Github - this gem links pull request from each commit between two branches, and extracts information from pull request."
  s.authors     = ["Jaclyn Chen"]
  s.email       = 'jaclyn.y.chen+ruby@gmail.com'
  s.files       = ["lib/github-csv-changelog.rb"]
  s.homepage    = 'https://github.com/jaclync/github-csv-changelog'
  s.license     = 'MIT'
  s.executables << 'github-csv-changelog'
end