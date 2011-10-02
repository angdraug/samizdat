# Samizdat engine environment setup
#
#   Copyright (c) 2002-2009  Dmitry Borodaenko <angdraug@debian.org>
#
#   This program is free software.
#   You can distribute/modify this program under the terms of
#   the GNU General Public License version 3 or later.
#
# vim: et sw=2 sts=2 ts=8 tw=0

$KCODE = 'utf8' if RUBY_VERSION < '1.9'

# Samizdat version
SAMIZDAT_VERSION = '0.6.2'

# :main:engine.rb

# used below
require 'cgi'
require 'digest/md5'
require 'singleton'
require 'drb'
require 'dbi'

# used by samizdat core
require 'jcode' if RUBY_VERSION < '1.9'   # multi-byte character support
require 'stringio'   # fix a conflict between Ruby 1.6 cgi.rb and yaml.rb
require 'tempfile'
require 'uri'
require 'rbconfig'
require 'delegate'
require 'open-uri'

# fix bug in standard cgi.rb
def CGI::escapeHTML(string)
  string.gsub(/&/n, '&amp;').gsub(/\"/n, '&quot;').gsub(/\'/n, '&#39;').gsub(/>/n, '&gt;').gsub(/</n, '&lt;')
end

# add to_time() to String and DateTime if it's not there
require 'time'
require 'date'

unless String.method_defined? 'to_time'
  class String
    def to_time
      Time.parse(self)
    end
  end
end

unless DateTime.method_defined? 'to_time'
  class DateTime
    def to_time
      Time.parse(self.to_s)
    end
  end
end

# samizdat engine
require 'samizdat/engine/gettext'
require 'samizdat/engine/exceptions'
require 'samizdat/engine/globals'
require 'samizdat/engine/helpers'
require 'samizdat/engine/site'
require 'samizdat/engine/dataset'

require 'samizdat/engine/request'
require 'samizdat/engine/session'
require 'samizdat/engine/password'

require 'samizdat/engine/model'
require 'samizdat/engine/view'
require 'samizdat/engine/controller'
require 'samizdat/engine/dispatcher'

# samizdat application
require 'samizdat/models/member'
require 'samizdat/models/message'
require 'samizdat/models/content'
require 'samizdat/models/tag'
require 'samizdat/models/moderation'

require 'samizdat/components/resource'
require 'samizdat/components/list'

require 'samizdat/engine/plugins'
