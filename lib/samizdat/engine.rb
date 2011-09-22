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

unless ''.methods.include? 'to_time'
  class String
    def to_time
      Time.parse(self)
    end
  end
end

unless DateTime.strptime.methods.include? 'to_time'
  class DateTime
    def to_time
      Time.parse(self.to_s)
    end
  end
end

# try to initialize GetText
begin
  require 'gettext'

  GetText.module_eval do
    #:nodoc: all source files and classes are equal
    def callersrc
      "samizdat"   # hack for GetText < 1.6.0
    end
    def bound_target(klass = nil)
      Object   # hack for GetText >= 1.6.0
    end
  end

  include GetText

  # workaround for API change in GetText 1.6.0
  major, minor = GetText::VERSION.split('.').collect {|i| i.to_i }
  if major < 1 or (1 == major and minor < 6) then
    # GetText < 1.6.0
    def samizdat_bindtextdomain(locale, path=nil)
      bindtextdomain('samizdat', path, locale, 'utf-8')
    end
  elsif major < 2
    # GetText < 2.0.0
    def samizdat_bindtextdomain(locale, path=nil)
      GetText::bindtextdomain('samizdat',
        :locale => locale,
        :charset => 'utf-8',
        :path => path)
    end
  else
    def samizdat_bindtextdomain(locale, path=nil)
      GetText::bindtextdomain('samizdat',
        :charset => 'utf-8',
        :path => path)
      GetText::set_locale(locale)
    end
  end
  major, minor = nil

rescue LoadError
  def _(msgid)
    msgid
  end
end

# samizdat engine
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
require 'samizdat/models/event'

require 'samizdat/components/resource'
require 'samizdat/components/list'

require 'samizdat/engine/plugins'
