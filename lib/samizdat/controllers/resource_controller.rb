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
    related, body =
      if @request.has_key?('page')
        [ false, @resource.parts.to_s ]
      elsif @request.has_key?('related_page')
        [ true, nil ]
      else
        [ true, @resource.page ]
      end

    if related 
      dataset = Tag.related_dataset(site, @id)

      if dataset.empty?
        related = false
      else
        page = (@request['related_page'] or 1).to_i
        rss_link = %{resource/#{@id}/rss}
        @feeds[ Tag.tag_title(@title) ] = rss_link
        foot = nav(dataset, :name => 'related_page') + nav_rss(rss_link)
      end
    end

    @content_for_layout = render_template('resource_index.rhtml', binding)
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
      tags = @member.allowed_to?('vote') ? tag_list(tag) : nil
      tags &&= [nil, _('SELECT TAG')] + tags
      tag = (tag ? (tag.id or tag.uriref) : nil)
      @content_for_layout = render_template('resource_vote.rhtml', binding)
      @title = _('Vote') + ': ' + @title
    end
  end

  # RSS feed of related resources
  #
  def rss
    feed_page('resource/' + @id.to_s) do |maker|
      @resource.render_feed(maker)
    end
  end

end
