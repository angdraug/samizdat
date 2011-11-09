# Samizdat moderation log
#
#   Copyright (c) 2002-2011  Dmitry Borodaenko <angdraug@debian.org>
#
#   This program is free software.
#   You can distribute/modify this program under the terms of
#   the GNU General Public License version 3 or later.
#
# vim: et sw=2 sts=2 ts=8 tw=0

class BlockedAccountsList < ResourcesList
  def initialize(request)
    @dataset = SqlDataSet.new(
      request.site, %{SELECT id FROM member WHERE password IS NULL ORDER BY id DESC}
    ) {|ds| ds.key = :id }
    super(request, @dataset, :list_item)
  end

  attr_reader :dataset
end

class ModeratorsList < ResourcesList
  def initialize(request)
    dataset = Member.find_who_can(request.site, 'moderate')
    super(request, dataset, :list_item)
  end
end

class ModerationController < Controller

  def index
    page = (@request['page'] or 1).to_i
    links = []

    if @id
      resource = Resource.new(@request, @id)
      title = ', ' + resource.title
      dataset = resource.moderation_log
    else
      dataset = Moderation.find(site)

      if Moderation.find_pending(site).size > 0
        links.push(%q{<p><a href="moderation/pending">} + _('Pending Moderation Requests') + '</a></p>')
      end

      if @request.moderate? and not BlockedAccountsList.new(@request).dataset.empty?
        links.push(%q{<p><a href="moderation/blocked">} + _('Blocked Accounts') + '</a></p>')
      end

      links.push(%q{<p><a href="moderation/who">} + _('Moderators') + '</a></p>')
    end

    log_table = [[_('Date'), _('Moderator'), _('Action'), _('Resource')]] +
      dataset[page - 1].map {|m|
        l = Moderation.new(site, m[:resource], m[:action], m[:moderator], m[:action_date])
        [
          format_date(l.date),
          l.moderator ? resource_href(l.moderator, Resource.new(@request, l.moderator).title) : '&nbsp;',
          _(Moderation::ACTION_LABELS[l.action]),
          Resource.new(@request, l.resource).list_item
        ]
      }

    links = 
      if links.empty?
        ''
      else
        box(_('Links'), links.join, 'links')
      end

    @title = _('Moderation Log') + title.to_s + page_number(page)
    @content_for_layout = links + box(@title, table(log_table, nav(dataset)))
  end

  def pending
    page = (@request['page'] or 1).to_i
    dataset = Moderation.find_pending(site)

    pending_table = [[_('Date'), _('Resource')]] + 
      dataset[page - 1].collect {|r|
        resource = Resource.new(@request, r[:resource])
        [ format_date(r[:action_date]), resource.short + resource.buttons ]
      }

    @title = _('Pending Moderation Requests') + page_number(page)
    @content_for_layout = box(
      @title, table(pending_table, nav(dataset)))
  end

  def blocked
    assert_moderate
    list_page(_('Blocked Accounts'), BlockedAccountsList)
  end

  def who
    list_page(_('Moderators'), ModeratorsList)
  end
end
