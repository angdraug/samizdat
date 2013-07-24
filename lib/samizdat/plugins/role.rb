# Samizdat role-based access control plugin
#
#   Copyright (c) 2002-2011  Dmitry Borodaenko <angdraug@debian.org>
#
#   This program is free software.
#   You can distribute/modify this program under the terms of
#   the GNU General Public License version 3 or later.
#
# vim: et sw=2 sts=2 ts=8 tw=0

require 'samizdat'
require 'samizdat/plugins/access'

class RolePlugin < AccessPlugin
  register_as 'role'

  def match?(member, action)
    @options.each do |role, actions|
      return true if
        member.access['role'].include?(role) and
        actions.include?(action)
    end

    false
  end

  # default roles: +guest+ (any user), +member+ (authenticated member)
  #
  # all other roles are matched against a member id and thus assume that user
  # is an authenticated member
  #
  def set_member_access(member)
    member.access['role'] = ['guest']

    if member.id.kind_of?(Integer)
      member.access['role'].push('member')

      db[:Role].filter(:member => member.id).select(:role).distinct.each do |r|
        member.access['role'].push(r[:role])
      end
    end
  end

  def display_member_access(member)
    roles = member.access['role']
    if roles.size > 2   # more than just a member
      roles[2, roles.size - 2].collect {|role| _(role) }.join(', ')
    else
      _(roles[-1])
    end
  end

  def find_who_can(action)
    roles = @options.collect {|role, actions|
      # fixme: report correctly when everyone is allowed to perform the action
      role if actions.include?(action) and not ['guest', 'member'].include?(role)
    }.compact
    return nil if roles.empty?
    %{SELECT DISTINCT member FROM Role WHERE role IN ('#{roles.join("', '")}')}
  end

  private

  def _rgettext_hack   # :nodoc:
    [ _('guest'), _('member'), _('moderator') ]
  end
end
