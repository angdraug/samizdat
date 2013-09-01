# Samizdat resource representation
#
#   Copyright (c) 2002-2011  Dmitry Borodaenko <angdraug@debian.org>
#
#   This program is free software.
#   You can distribute/modify this program under the terms of
#   the GNU General Public License version 3 or later.
#
# vim: et sw=2 sts=2 ts=8 tw=0

require 'samizdat'
require 'samizdat/helpers/application_helper'
require 'samizdat/helpers/message_helper'

class Resource
  include SiteHelper

  # get reference for _request_, validate _id_, determine
  # _type_
  #
  def initialize(request, id)
    @request = request
    @site = @request.site

    @id = Model.validate_id(id)
    @id or raise ResourceNotFoundError, id.to_s

    @type = cache.fetch_or_add(%{resource_type/#{@id}}) do
      r = db[:resource][:id => @id] or raise ResourceNotFoundError, @id.to_s

      if r[:uriref]
        'Uriref'
      elsif r[:literal]
        'Literal'
      else   # internal resource
        case r[:label]
        when 'member', 'message', 'statement', 'vote'
          r[:label].capitalize
        else
          raise RuntimeError,
            sprintf(_("Unknown resource type '%s'"), Rack::Utils.escape_html(r[:label]))
        end
      end
    end

    @type.untaint
    @component = instance_eval(@type + 'Component').new(@request, @id)
  end

  attr_reader :request, :id, :type

  def to_i
    @id
  end

  def _rgettext_hack   # :nodoc:
    [ _('Uriref'), _('Literal'), _('Member'), _('Message'), _('Statement'), _('Vote') ]
  end
  private :_rgettext_hack

  # delegate known actions to the component and cache results when appropriate
  #
  def method_missing(action, *args)
    key = cache_key(action, *args)
    case key
    when :uncacheable
      @component.send(action, *args)
    when String
      cache.fetch_or_add(key) do
        @component.send(action, *args)
      end
    else
      super
    end
  end

  private

  # compose a unique cache key for resource component action
  #
  # when necessary, include request parameters in the key
  #
  # returns +:uncacheable+ if action cannot be cached
  #
  def cache_key(action, *args)
    case action
    when :links
      %{resource/#{@id}/#{action}}
    when :feeds
      %{resource/#{@id}/#{action}/#{@request.accept_language.join(':')}}
    when :title, :list_item, :short, :full
      %{resource/#{@id}/#{action}/#{@request.accept_language.join(':')}/#{@request['page'].to_i}}
    when :page, :parts, :buttons, :moderation_log, :rss, :render_feed
      :uncacheable
    else
      nil
    end
  end
end

class ResourceComponent
  include ApplicationHelper

  def initialize(request, id)
    self.request = request

    @id = Model.validate_id(id)
    @id or raise ResourceNotFoundError, id.to_s

    @title = nil
    @info = nil

    @feeds = {}
    @links = {}
  end

  attr_reader :feeds, :links

  # resource title (HTML-escaped)
  #
  def title
    escape_title(@title.to_s)
  end

  # render resource as a list item
  #
  def list_item
    resource(@id, title, info)
  end

  # short rendering of the resource
  #
  def short
    info
  end

  # full rendering of the resource
  #
  def full
    short
  end

  def tags
    return '' unless show_tags?

    dataset = RdfDataSet.new(site, %{
SELECT ?tag
WHERE (rdf::subject ?stmt #{@id})
      (rdf::predicate ?stmt dc::relation)
      (rdf::object ?stmt ?tag)
      (s::rating ?stmt ?rating FILTER ?rating > 0)
ORDER BY ?rating DESC})

    tags = {}
    dataset[0].each {|r|
      tag = Tag.new(site, r[:tag], @id)
      tags[tag.id] = tag   # assume it has an id as we got it from the db
    }

    if @member.id
      Tag.find_special_tags(site, true) do |tag_id|
        tag = Tag.new(site, tag_id, @id)
        tags[tag_id] = tag if tag.display_vote_link?(@member)
      end
    end

    tags = tags.values.find_all {|t| t.id != @id }.sort_by {|t| -t.sort_index }
    render_template('resourcecomponent_tags.rhtml', binding)
  end

  def parts
    dataset = RdfDataSet.new(site, %{
SELECT ?subtag
WHERE (s::subTagOf ?subtag :tag)
ORDER BY ?subtag},
      :tag => @id) {|ds| ds.key = :subtag }

    unless dataset.empty?
      parts_list(
        dataset, _('Subtags'),
        :id => 'subtags',
        :param => 'subtags_page',
        :render => :title)
    end
  end

  def buttons
    nil
  end

  # render resource itself along with tags, parts, and buttons
  #
  # only one resource per page may be rendered in this mode
  #
  def page
    full << tags << parts.to_s << buttons.to_s
  end

  def moderation_log(page = 1)
    Moderation.find(site, @id)
  end

  # add RSS item of the resource to _maker_ feed
  #
  # _maker_ is assumed to provide RSS::Maker API
  #
  def rss(maker)
    item = maker.items.new_item
    item.link = File.join(@request.base, @id.to_s)
    item.date = rdf.get_property(@id, 'dc::date').to_time
    item.title = title
    item.description = info
  end

  # RSS feed of related resources. See also ApplicationHelper#feed_page.
  #
  def render_feed(maker)
    maker.channel.title = maker.channel.description = config['site']['name'] +
      ' / ' + Tag.tag_title(@title)
    maker.channel.link = File.join(@request.base, @id.to_s)

    Tag.related_dataset(site, @id)
  end

  private

  attr_reader :info

  def show_tags?
    true
  end

  def parts_list(dataset, title, options = {})
    # fixme: check consistency of default value for page_parameter
    page_parameter = (options[:param] or 'page')
    page = (@request[page_parameter] or 1).to_i
    n = nav(dataset, :name => page_parameter)
    n << options[:nav].to_s

    entries = dataset[page - 1].map do |r|
      resource = Resource.new(@request, r[dataset.key])
      case options[:render]
      when Proc
        yield resource
      when :title
        resource_href(resource.id, resource.title)
      when :list_item, :full
        resource.call(options[:render])
      else
        resource.short
      end
    end
    entries =
      case options[:render]
      when :title
        entries.join(', ') + n
      else
        list(entries, n)
      end

    box(title + page_number(page), entries, options[:id])
  end
end

class UrirefComponent < ResourceComponent
  def initialize(request, id)
    super

    uriref = db[:resource].filter(:id => @id).get(:label)

    @title = rdf.ns_shrink(uriref)
    @title.gsub!(/\Atag::/, '') and @title = _(@title)   # tag is a special case

    @info = '<div>' + sprintf(_('refers to <a href="%s">external uriref</a>'), uriref) + '</div>'
    # todo: select all statements with this subject
  end
end

class LiteralComponent < ResourceComponent
  def initialize(request, id)
    super

    value = db[:resource].filter(:id => @id).get(:label)
    uriref = @request.base + @id.to_s

    @title = label
    @info = %{<a href="#{uriref}">#{rdf.ns_shrink(uriref)}</a> = #{Rack::Utils.escape_html(value)}}
  end
end

class MessageComponent < ResourceComponent
  include MessageHelper

  def initialize(request, id)
    super

    @message = Message.cached(site, @id)

    # use translation to preferred language if available
    @translation = @message.select_translation(@request.accept_language)
    @title = @translation.content.title

    # navigation links
    @links['made'] = @message.creator.id
    @links['up'] = @message.parent if @message.parent
  end

  def list_item
    if @message.nrelated > 0
      resource(@id, Tag.tag_title(title), info)
    else
      super
    end
  end

  def short
    # rely on ApplicationHelper#message to take care of translation
    message(@message, :short)
  end

  def full
    message(@message, :full)
  end

  def parts
    parts = super

    unless @message.parts.empty?   # add parts
      parts = parts.to_s +
        parts_list(
          @message.parts_dataset, _('Parts'),
          :id => 'parts',
          :param => 'parts_page',
          :render => :title)
    end

    if @message.nreplies > 0   # add replies
      if 'all' == @request['replies']
        replies = box(_('Replies'), render_all_replies, 'replies')

      else
        dataset = RdfDataSet.new(site, %{
SELECT ?msg
WHERE (s::inReplyTo ?msg :parent)
      #{exclude_hidden('?msg')}
ORDER BY ?msg}, :parent => @id) {|ds| ds.key = :msg }

        if @message.nreplies != @message.nreplies_all
          n = %{<div class="nav"><a href="#{@id}?replies=all">} +
            _('show all replies') + '</a></div>'
        end

        replies = parts_list(dataset, _('Replies'), :id => 'replies', :nav => n)
      end

      parts = parts.to_s + replies
    end

    parts
  end

  def buttons
    message_buttons(@message)
  end

  def moderation_log(page = 1)
    Moderation.find(site, @id, :message => true)
  end

  # add RSS item of the message to _maker_ feed
  #
  # _maker_ is assumed to provide RSS::Maker API
  #
  def rss(maker)
    item = maker.items.new_item
    item.link = @request.base + @id.to_s
    item.date = @message.first_date.to_time

    item.title = escape_title(@translation.content.title)
    item.dc_language = @translation.lang

    # message body (not standards compliant, but supported by most readers)
    item.description = @translation.content.render(@request, :short)
  end

  private

  def info
    message_info(@message, :list)
  end

  def show_tags?
    @message.part_of.nil?   # don't offer to tag parts
  end

  def render_all_replies(id = @id)
    dataset = RdfDataSet.new(site, %{
SELECT ?msg
WHERE (s::inReplyTo ?msg :id)
      #{exclude_hidden('?msg')}
ORDER BY ?msg}, :id => id)

    return '' if dataset.empty?

    '<div class="replies">' + dataset[0].map {|r|
      # fixme: limit recursion, detect loops
      reply = r[:msg]
      Resource.new(@request, reply).short + render_all_replies(reply)
    }.join + '</div>'
  end
end

class MemberComponent < ResourceComponent
  def initialize(request, id)
    super

    member = Member.cached(site, @id)
    @login = member.login
    @title = member.full_name
    @location = member.location.to_s
    @moderator = member.allowed_to?('moderate')
    @info = _('Login') + ": #{@login}"

    @messages_dataset = member.messages_dataset
    @feeds[@title] = File.join(@location, 'rss') unless @messages_dataset.empty?

    # used to check if account is blocked
    m = db[:member][:id => @id]
    if m[:password].nil?
      @blocker = yaml_hash(m[:prefs])['blocked_by'].to_i
      if @blocker > 0
        @blocker_name = db[:member].filter(:id => @blocker).get(:full_name)
      end
    end
  end

  def full
    body = '<p>' + @info + '</p>'

    if @blocker_name
      body << '<p>' <<
        sprintf(
          _('Account <a href="%s">blocked by moderator</a>: %s.'),
          'moderation/' + @id.to_s,
          resource_href(@blocker, escape_title(@blocker_name))
        ) << '</p>'
    end

    box(nil, body)
  end

  def tags
    ''
  end

  def parts
    unless @messages_dataset.empty?
      parts_list(@messages_dataset,
                 _('Latest Messages'),
                 :nav => nav_rss(@feeds[@title]))
    end
  end

  def buttons
    if @request.moderate? and not @moderator
      # show block/unblock button unless that member is a moderator, too
      %{<div class="foot"><a class="moderator_action" href="member/#{@id}/} <<
        (@blocker ? 'unblock' : 'block') << '">' <<
        (@blocker ? _('UNBLOCK') : _('BLOCK')) <<
        %{</a></div>\n}
    end
  end

  # RSS feed of latest messages.
  #
  def render_feed(maker)
    maker.channel.title = maker.channel.description = @title
    maker.channel.link = File.join(@request.base, @location)

    @messages_dataset
  end
end

class StatementComponent < ResourceComponent
  def initialize(request, id)
    super

    @title = _('Statement') + ' ' + @id.to_s

    r = rdf.fetch(%q{
SELECT ?predicate, ?subject, ?object
WHERE (rdf::predicate :id ?predicate)
      (rdf::subject :id ?subject)
      (rdf::object :id ?object)}, :id => @id
    ).first
    r.each {|field, value| instance_variable_set('@' + field.to_s, value) }

    @info = %{
(<a href="#{@predicate}">} + _('Predicate') + %{ #{@predicate}</a>,
<a href="#{@subject}">} + _('Subject') + %{ #{@subject}</a>,
<a href="#{@object}">} + _('Object') + %{ #{@object}</a>)}
  end

  def short
    n = [_('Predicate'), _('Subject'), _('Object')]
    [@predicate, @subject, @object].collect {|resource|
      box(n.shift, Resource.new(@request, resource).list_item)
    }.join
  end

  def full
    short << box(nil,
      '<p><a href="query/run?q=' <<
      Rack::Utils.escape("SELECT ?vote WHERE (s::voteProposition ?vote #{@id})") <<
      '">' << _('Votes') << '</a></p>')
  end
end

class VoteComponent < ResourceComponent
  def initialize(request, id)
    super

    @title = _('Vote') + ' ' + @id.to_s

    v = rdf.fetch(%q{
SELECT ?date, ?stmt, ?member, ?rating
WHERE (dc::date :id ?date)
      (s::voteProposition :id ?stmt)
      (s::voteMember :id ?member)
      (s::voteRating :id ?rating)}, :id => @id).first
    @stmt = v[:stmt]
    @voter = v[:member]

    name = escape_title(Member.cached(site, @voter).full_name)
    @info = sprintf(_('<a href="%s">%s</a> gave rating %4.2f to the <a href="%s">Statement %s</a> on %s.'),
      @voter, name, v[:rating], @stmt, @stmt, format_date(v[:date]).to_s)

    @links['made'] = @voter
  end

  def short
    box(nil, @info) <<
      box(_('Vote Proposition'), Resource.new(@request, @stmt).short)
  end
end
