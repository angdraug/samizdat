# Samizdat spam filtering plugin superclass
#
#   Copyright (c) 2002-2009  Dmitry Borodaenko <angdraug@debian.org>
#
#   This program is free software.
#   You can distribute/modify this program under the terms of
#   the GNU General Public License version 3 or later.
#
# vim: et sw=2 sts=2 ts=8 tw=0

require 'samizdat'

# raised on suspicion of spamming
class SpamError < UserError; end

class SpamPlugin < Plugin
  def initialize(site, options)
    super

    if @options.kind_of?(Hash)
      @roles = @options['check_roles']
    end
    @roles ||= []
  end

  def api
    'spam'
  end

  def match?(*actions)
    actions.each {|a| respond_to?(a) or return false }
    true
  end
end
