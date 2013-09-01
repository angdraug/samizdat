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
        links.push(["moderation/pending", _('Pending Moderation Requests')])
      end

      if @request.moderate? and not BlockedAccountsList.new(@request).dataset.empty?
        links.push(["moderation/blocked", _('Blocked Accounts')])
      end

      links.push(["moderation/who", _('Moderators')])
    end

    @title = _('Moderation Log') + title.to_s + page_number(page)
    log = dataset[page - 1].map do |m|
      Moderation.new(site, m[:resource], m[:action], m[:moderator], m[:action_date])
    end
    foot = nav(dataset)
    @content_for_layout = render_template('moderation_index.rhtml', binding)
  end

  def pending
    page = (@request['page'] or 1).to_i
    dataset = Moderation.find_pending(site)

    @title = _('Pending Moderation Requests') + page_number(page)
    foot = nav(dataset)
    @content_for_layout = render_template('moderation_pending.rhtml', binding)
  end

  def blocked
    assert_moderate
    list_page(_('Blocked Accounts'), BlockedAccountsList)
  end

  def who
    list_page(_('Moderators'), ModeratorsList)
  end
end
