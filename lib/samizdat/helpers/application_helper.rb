# Samizdat HTML helpers
#
#   Copyright (c) 2002-2011  Dmitry Borodaenko <angdraug@debian.org>
#
#   This program is free software.
#   You can distribute/modify this program under the terms of
#   the GNU General Public License version 3 or later.
#
# vim: et sw=2 sts=2 ts=8 tw=0

require 'samizdat'

# All helpers descendant from ApplicationHelper assume that including class
# provides following instance variables: @request, @site, @session, @member. To
# ensure that, invoke self.request=() before using any helper methods.
#
module ApplicationHelper
  include SiteHelper

  # Set up instance variables for use in helpers.
  #
  def request=(request)
    @request = request
    @site = @request.site
    @session = @request.session
    @member = Member.cached(@request.site, @session.member)
  end

  STRIP_TAGS_PATTERN = Regexp.new(/<[^>]*?>/).freeze

  def strip_tags(text)
    text.gsub(STRIP_TAGS_PATTERN, '')
  end

  # truncate _string_ to the title limit and escape HTML characters in it
  #
  def escape_title(string)
    CGI.escapeHTML(limit_string(string))
  end

  # transform date to a standard string representation
  #
  def format_date(date)
    date = date.to_time if date.respond_to? :to_time   # duck
    if site.timezone and date.kind_of? Time
      date = site.timezone.utc_to_local(
        SystemTimezone.instance.timezone.local_to_utc(date))
    end
    date = date.strftime '%Y-%m-%d %H:%M' if date.respond_to? :strftime
    date
  end

  # title for logo link in the page header
  #
  def logo_link_title
    config['site']['name'] + ': ' + _('Front Page')
  end

  # hyperlink
  #
  def link(location, text, title = nil)
    %{<a href="#{location}"} +
      (title ? %{ title="#{title}"} : '') +
      %{>#{text}</a>}
  end

  # wrap title and content into a CSS-rendered box
  #
  def box(title, content, id=nil)
    box_title = %{<div class="box-title">#{title}</div>} if title
    box_id = %{ id="#{id}"} if id
%{<div class="box"#{box_id}>
  #{box_title}<div class="box-content">
#{content}
  </div>
</div>\n}
  end

  # page number to be appended to a page title
  #
  def page_number(page)
    page > 1 ? sprintf(_(', page %s'), page) : ''
  end

  # navigation link to a given page number
  #
  def nav(dataset, options = {})
    name = (options[:name] or 'page')
    page = (options[:page] or (@request[name] or 1).to_i)
    route = (options[:route] or File.join(@request.uri_prefix, @request.route) + '?')

    return '' if page < 1 or dataset.size <= dataset.limit

    max_page = (dataset.size.to_f / dataset.limit).ceil
    return '' if page > max_page

    link = "#{route}#{name}="
    pages = []

    range_start = page - 2
    range_start = 1 if range_start < 1
    range_end = page + 2
    range_end = max_page if range_end > max_page

    if range_start > 1
      pages << 1
      if range_start > 2
        pages << ellipsis
      end
    end

    range_start.upto(range_end) do |i|
      pages << i
    end

    if range_end < max_page
      if range_end < max_page - 1
        pages << ellipsis
      end
      pages << max_page
    end

    pages = _('pages: ') + pages.collect {|i|
      (i.kind_of?(Integer) and i != page)?
        %{<a href="#{link}#{i}">#{i}</a>} : i
    }.join(' ')

    pages << %{, <a href="#{link}#{page + 1}">} + _('next page') + '</a>' if
      page < max_page

    '<div class="nav">' << pages << "</div>\n"
  end

  # add link to RSS rendering of the page
  #
  def nav_rss(link)
    link ? %{<div class="nav"><a href="#{link}">rss 1.0</a></div>} : ''
  end

  # resource list with navigation link
  #
  def list(list, nav, foot='')
    foot = %{<div class="foot">\n#{foot + nav}</div>\n} unless
      '' == foot and '' == nav
    even = 1
    %{<ul>\n} <<
    list.collect {|li|
      even = 1 - even
      %{<li#{' class="even"' if even == 1}>#{li}</li>\n}
    }.join << %{</ul>\n} << foot
  end

  # resource table with navigation link
  #
  def table(table, nav, foot='')
    foot = %{<div class="foot">\n#{foot + nav}</div>\n} unless
      '' == foot and '' == nav
    even = 1
    %{<table>\n<thead><tr>\n} <<
    table.shift.collect {|th| "<th>#{th}</th>\n" }.join <<
    %{</tr></thead>\n<tbody>\n} <<
    table.collect {|row|
      even = 1 - even   # todo: a CSS-only way to do this
      %{<tr#{' class="even"' if even == 1}>\n} << row.collect {|td|
        "<td>#{td or '&nbsp;'}</td>\n"
      }.join << "</tr>\n"
    }.join << %{</tbody></table>\n} << foot
  end

  # type can be any of the following:
  #
  # [:label]
  #   wrap label _value_ in a <div> tag and associate it with _name_ field
  #   (caveat: ids are not unique across multiple forms)
  # [:br] line break
  # [:textarea] fixed text area 70x20 with _value_
  # [:select] _value_ is an array of options or pairs of [option, label]
  # [:submit] _value_ is a button label
  # [standard HTML input type] copy _type_ as is into <input> tag
  #
  def form_field(type, name=nil, value=nil, default=nil)
    value = CGI.escapeHTML(value) if value.class == String
    attr = %{ name="#{name}"} if name
    attr += %{ id="f_#{name}"} if name and :label != type
    attr += ' disabled="disabled"' if name and :disabled == default
    case type
    when :br then %{<br />\n}
    when :label
      for_name = %{ for="f_#{name}"} if name
      %{<div class="label"><label#{for_name}>#{value}</label></div>\n}
    when :textarea
      %{<textarea#{attr} cols="70" rows="20">#{value}</textarea>\n}   # mind rexml
    when :select, :select_submit
      attr += ' onchange="submit()"' if :select_submit == type
      %{<select#{attr}>\n} + value.collect {|option|
        v, l = (option.class == Array)? option : [option, option]
        selected = (v == default)? ' selected="selected"' : ''
        %{    <option#{selected} value="#{v}">#{l}</option>\n}
      }.join + "</select>\n"
    when :submit, :submit_moderator
      value = _('Submit') if value.nil?
      %{<input#{attr} type="submit" value="#{value}" class="#{type}" />\n}
    else
      if :checkbox == type
        attr += ' checked="checked"' if value
        value = 'true'
      end
      %{<input#{attr} type="#{type}" value="#{value}" />\n}
    end
  end

  # normalize form action location
  #
  def action_location(action = nil)
    action ||= @request.route   # default to current location
    unless absolute_url?(action)
      action = File.join(@request.uri_prefix, action)   # relative to site base
    end
    action
  end

  # Wrap a list of form fields into a form. If a field is a String, it is
  # included as is; if it is an array, it is passed as parameters to
  # form_field().
  #
  # _action_ should always be relative to site base (start with '/'), default
  # _action_ is current location.
  #
  # Automatically detects if multipart/form-data is necessary.
  #
  def form(action, *fields)
    if fields.assoc(:file)
      enctype = ' enctype="multipart/form-data"'
    end

    %{<form action="#{action_location(action)}" method="post"#{enctype}><div>\n} <<
      fields.collect {|param|
        case param
        when String
          param
        when Array
          form_field(*param)
        else
          ''
        end
      }.join << "</div></form>\n"
  end

  def action_token_key
    %{action_token/#{@session.login}}
  end

  # Wrapper around form() to protect logged in members against CSRF by adding a
  # hidden action confirmation hash to the form and storing it in cache.
  #
  def secure_form(action, *fields)
    if @session.member
      fields.push [:hidden, 'action_token', @request.action_token]
    end
    form(action, *fields)
  end

  # Sort tags by name, alter font size in proportion to tag usage.
  #
  def tag_cloud
    data = Tag.find_tags(site)
    max_tag, max_usage = data.first
    return '' unless max_usage and max_usage > 0

    data.collect {|tag, usage|
      [ tag, usage, Tag.new(site, tag).name(@request) ]

    }.sort_by {|tag, usage, title| title.downcase }.collect {|tag, usage, title|
      font_size = 75 + 75 * usage / max_usage

      %{<span style="font-size: #{font_size}%">} <<
        %{<a href="#{tag}">#{title}</a></span>}
    }.join("\n")
  end

  # drop-down menu to select tag from a list
  #
  def tag_select(tag = nil)
    return [] unless @member.allowed_to?('vote')

    tags = (Tag.find_tags(site).transpose[0] or [])
    if tag.kind_of?(Tag) and not tags.include?(tag.id)
      # make sure the tag we want is in the list
      tags.unshift((tag.id or tag.uriref))
    end
    tags.collect! {|t| [ t, Tag.new(site, t).name(@request) ] }
    tags = tags.sort_by {|t, name| name.downcase }
    tags.unshift [nil, _('SELECT TAG')]

    [ [:label, 'tag', _('Select a tag that this resource will be related to')],
        [:select, 'tag', tags, (tag ? (tag.id or tag.uriref) : nil)] ]
  end

  # form fields for vote on tag rating
  #
  def tag_fields(tag)
    return [] unless @member.allowed_to?('vote')

    fields = tag_select(tag)

    if @request.advanced_ui?
      fields.push(
        [:label, 'tag_id', _("If the tag you want is not in the list above, enter its id (a number)")],
          [:text, 'tag_id']
      )
    end

    fields.push(
      [:label, 'rating', _('Give a rating of how strongly this resource is related to the tag that you selected')],
        [:select, 'rating', [
          [-2, _('-2 (No)')],
          [-1, _('-1 (Not Likely)')],
          [0, _('0 (Uncertain)')],
          [1, _('1 (Likely)')],
          [2, _('2 (Yes)')] ], 0]
    )
  end

  # render link to resource with a tooltip
  #
  # _title_ should be HTML-escaped
  #
  def resource_href(id, title)
    return '' unless title.kind_of? String
    id.nil? ? limit_string(title) :
      '<a title="'+_('Click to view the resource')+%{" href="#{id}">#{limit_string(title)}</a>}
  end

  # Render a link to a member resource.
  #
  def member_link(member)
    if member.guest?
      _('guest')
    else
      link = config['plugins']['route'].include?('blog') ?
        'blog/' + member.login : member.id
      %{<a href="#{member.location}">#{escape_title(member.full_name)}</a>}
    end
  end

  # render resource description for resource listing
  #
  # _title_ should be HTML-escaped
  #
  def resource(id, title, info)
%{<div class="resource">
<div class="title">#{resource_href(id, title)}</div>
<div class="info">#{info}</div>
</div>\n}
  end

  # Wrap a page around a ResourceList.
  #
  def list_page(title, list_class)
    @feeds.delete_if {|t, l| t != title }
    list = list_class.new(@request)
    content = list.to_s
    content << '<div class="foot">' << nav_rss(@feeds[title]) << '</div>' if @feeds[title]

    @title = title + page_number(list.page)
    @content_for_layout = box(@title, content)
  end

  # Render an RSS feed page. Pass it a block that sets channel title,
  # description, and link, and returns a list of ids of resources to be
  # included in the feed.
  #
  def feed_page(cache_key)
    @request.headers['type'] = 'application/xml'
    @layout = nil

    @content_for_layout = cache.fetch_or_add(
      'rss/' + cache_key + '/' + @request.accept_language.join(':')) do

      require 'rss/maker'
      RSS::Maker.make("1.0") {|maker|
        yield(maker).collect do |id,|
          Resource.new(@request, id).rss(maker)
        end

        maker.channel.about = File.join(@request.base, @request.env['REQUEST_URI'])

        if config['site']['icon']
          maker.image.title = config['site']['name']
          maker.image.url = File.join(@request.base, config['site']['icon'])
        end
      }.to_s
    end
  end

  # default language on the site is the first language in the languages list
  #
  def default_language
    config['locale']['languages'].first
  end

  def language_names
    cache.fetch_or_add('language_names') do
      map = {}
      config['locale']['languages'].each do |lang|
        lang.untaint
        name = @request.temporary_language(lang) do
          _('(name that this language calls itself)')
        end
        next if '(name that this language calls itself)' == name   # broken localization
        map[lang] = name
      end
      map
    end
  end
end
