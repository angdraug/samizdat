# Samizdat resource display and focus management
#
#   Copyright (c) 2002-2011  Dmitry Borodaenko <angdraug@debian.org>
#
#   This program is free software.
#   You can distribute/modify this program under the terms of
#   the GNU General Public License version 3 or later.
#
# vim: et sw=2 sts=2 ts=8 tw=0

class ResourceController < Controller
  def initialize(request, id=nil)
    super

    @resource = Resource.new(@request, @id)

    # special case: force untranslated title to go with full rendering of a message
    @title = ('Message' == @resource.type) ?
      escape_title(Message.cached(site, @id).content.title) :
      @resource.title

    @feeds.update(@resource.feeds)
    @links.update(@resource.links)
  end

  # render resource
  #
  def index
    @content_for_layout =
      if @request.has_key?('page')
        box(@title, @resource.parts.to_s)
      elsif @request.has_key?('related_page')
        related
      else
        related + box(@title, @resource.page)
      end
  end

  # vote on tag rating
  #
  def vote
    @member.assert_allowed_to('vote')

    tag, tag_id, rating = @request.values_at %w[tag tag_id rating]
    if tag_id = Model.validate_id(tag_id)
      # manual entry overrides selection
      tag = tag_id
    end
    tag = Tag.new(site, tag, @id) if tag

    if tag.kind_of?(Tag) and rating   # commit vote
      @request.assert_action_confirmed
      # rating is validated by Tag#vote
      tag.vote(@member, rating)
      @request.redirect(@id)

    else   # display vote form
      vote_title = _('Vote') + ': ' + @title
      vote_form = secure_form(
        nil,
        *tag_fields(tag) +
        [ [:br], [:submit, nil, _('Submit')] ])

      @content_for_layout =
        box(vote_title, vote_form) +
        box(@title, @resource.full)
      @title = vote_title
    end
  end

  # RSS feed of related resources
  #
  def rss
    feed_page('resource/' + @id.to_s) do |maker|
      @resource.render_feed(maker)
    end
  end

  private

  # related resources
  #
  def related
    page = (@request['related_page'] or 1).to_i
    dataset = Tag.related_dataset(site, @id)

    return '' if dataset.empty?

    rss_link = %{resource/#{@id}/rss}
    @feeds[ Tag.tag_title(@title) ] = rss_link
    box(
      Tag.tag_title(@title) + page_number(page),
      list(
        dataset[page - 1].map {|r| Resource.new(@request, r[:related]).short },
        nav(dataset, :name => 'related_page') << nav_rss(rss_link)
      )
    )
  end
end
