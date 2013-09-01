# Samizdat engine environment setup
#
#   Copyright (c) 2002-2011  Dmitry Borodaenko <angdraug@debian.org>
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
require 'rack'
require 'digest/md5'
require 'singleton'
require 'drb'
require 'sequel'

# used by samizdat core
require 'jcode' if RUBY_VERSION < '1.9'   # multi-byte character support
require 'stringio'   # fix a conflict between Ruby 1.6 cgi.rb and yaml.rb
require 'tempfile'
require 'uri'
require 'rbconfig'
require 'delegate'
require 'open-uri'

# samizdat engine
require 'samizdat/engine/time'
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

require 'samizdat/engine/inline'

# samizdat application
require 'samizdat/models/member'
require 'samizdat/models/message'
require 'samizdat/models/content'
require 'samizdat/models/tag'
require 'samizdat/models/moderation'

require 'samizdat/components/resource'
require 'samizdat/components/list'

require 'samizdat/engine/plugins'
