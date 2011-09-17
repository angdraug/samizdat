# Samizdat engine singleton objects
#
#   Copyright (c) 2002-2009  Dmitry Borodaenko <angdraug@debian.org>
#
#   This program is free software.
#   You can distribute/modify this program under the terms of
#   the GNU General Public License version 3 or later.
#
# vim: et sw=2 sts=2 ts=8 tw=0

require 'samizdat'
require 'whitewash'

class DefaultConfig
  include Singleton

  # Look up config files in one of given directories, by default look in /etc,
  # /usr/share, /usr/local/share, and current directory.
  #
  DIRS = [ '/etc/samizdat/',
           Config::CONFIG['datadir'] + '/samizdat/',
           '/usr/local/share/samizdat/',
           '.' ]

  def initialize
    @config = load_yaml_file(find_file(@file, DIRS), true)
  end

  attr_reader :config
end


# Global RDF-relational mapping.
#
class DefaultRdfConfig < DefaultConfig
  def initialize
    @file = 'rdf.yaml'
    super
  end
end


# Default settings common for all sites.
#
class DefaultSiteConfig < DefaultConfig
  def initialize
    @file = 'defaults.yaml'
    super
  end
end


class SystemTimezone
  include Singleton

  def initialize
    @timezone = TZInfo::Timezone.get(
      File.open('/etc/timezone') {|f| f.read.chomp.untaint })
  end

  attr_reader :timezone
end


class WhitewashSingleton < Whitewash
  include Singleton
end
