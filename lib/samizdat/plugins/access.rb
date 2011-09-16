# Samizdat access control plugin superclass
#
#   Copyright (c) 2002-2009  Dmitry Borodaenko <angdraug@debian.org>
#
#   This program is free software.
#   You can distribute/modify this program under the terms of
#   the GNU General Public License version 3 or later.
#
# vim: et sw=2 sts=2 ts=8 tw=0

require 'samizdat'

class AccessPlugin < Plugin
  def api
    'access'
  end

  # matches if plugin is applicable for this user and this action
  #
  # what a match really means (allowed or denied) depends on allow?() method
  #
  def match?(member, action)
    false
  end

  # returns +true+ if plugin matches when user is allowed to perform an action,
  # +false+ if plugin matches when user is denied
  #
  # action is authorized if there is at least one matching allowing plugin and no
  # matching denying plugins
  #
  def allow?
    true
  end

  # update Member object with access information that will allow to match the
  # user against this plugin
  #
  def set_member_access(member)
  end

  def display_member_access(member)
    ''
  end

  # Returns an SQL query that selects all members who can perform _action_.
  # Queries from all plugins are joined by UNION clause and sorted by +member+
  # field (see Member.find_who_can), thus the query must return a single row
  # labeled 'member' and must not contain an ORDER BY clause.
  #
  def find_who_can(action)
  end

  private

  def _rgettext_hack   # :nodoc:
    [ _('post'), _('vote'), _('moderate') ]
  end
end
