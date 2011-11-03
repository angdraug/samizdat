# Samizdat tag management plugin superclass
#
#   Copyright (c) 2002-2011  Dmitry Borodaenko <angdraug@debian.org>
#
#   This program is free software.
#   You can distribute/modify this program under the terms of
#   the GNU General Public License version 3 or later.
#
# vim: et sw=2 sts=2 ts=8 tw=0

require 'samizdat'

class TagPlugin < Plugin
  def api
    'tag'
  end

  # tags, ordered by number of related resources
  #
  # returns [ [tag_id, usage], ... ]
  #
  def find_all
    []
  end

  def vote_action
    'vote'
  end

  def allowed_to_vote?(member)
    member.kind_of?(Member) and member.id and member.allowed_to?(vote_action)
  end

  # may _resource_ be related to a matching tag?
  #
  def applicable_to?(resource)
    true
  end

  def visible?
    true
  end

  def may_reply_to_related?
    true
  end

  # invoked before _member_'s vote on the _resource_ is recorded
  #
  def pre_vote(member, resource)
    allowed_to_vote?(member) or raise AuthError,
      _('You are not allowed to vote about this tag.')
    applicable_to?(resource) or raise UserError,
      _('This tag cannot be related to this resource.')
  end

  private

  # some tags may be sensitive about a related resource being a reply
  #
  def is_a_reply?(resource)
    not rdf.get_property(resource, 's::inReplyTo').nil?
  end
end
