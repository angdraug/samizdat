# Samizdat HTML helpers for Resource components
#
#   Copyright (c) 2002-2009  Dmitry Borodaenko <angdraug@debian.org>
#
#   This program is free software.
#   You can distribute/modify this program under the terms of
#   the GNU General Public License version 3 or later.
#
# vim: et sw=2 sts=2 ts=8 tw=0

require 'samizdat/helpers/application_helper'

module ResourceHelper
  include ApplicationHelper

  # wrap tag name and rating in <span> tags
  #
  def tag_info(related, tag)
    return '' if tag.id == related   # never relate resource to itself

    info = tag.name(@request)
    info = resource_href(tag.id, info) if tag.id
    info << ': ' << tag.print_rating
    info << ' (<a title="' << _('Click to vote on how this resource is related to this tag') <<
      '" href="resource/' << related.to_s << '/vote' <<
      '?tag=' << CGI.escape((tag.id or tag.uriref).to_s) <<
      '">' << _('vote') <<
      '</a>)' if tag.allowed_to_vote?(@member)

    '<p>' + info + "</p>\n"
  end

  # list supplied tags using tag_info
  #
  def tag_box(related, tags)
    fbox = ''

    unless tags.empty?
      fbox << tags.sort_by {|t| -t.sort_index }.collect {|tag|
        tag_info(related, tag)
      }.join
    end

    if @member.allowed_to?('vote')
      fbox <<
        '<p><a class="action" title="' <<
        _('Click to add a tag related to this resource') <<
        %{" href="resource/#{related}/vote">} <<
        _('Add a tag') <<
        '</a></p>'
    end

    unless fbox.empty?
      fbox = box(_('Tags'), fbox, 'tags')
    end

    fbox
  end
end
