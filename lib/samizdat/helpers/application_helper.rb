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
    Rack::Utils.escape_html(limit_string(string))
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

  # wrap title and content into a CSS-rendered box
  #
  def box(title, content, id=nil)
    render_template('applicationhelper_box.rhtml', binding)
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

    render_template('applicationhelper_nav.rhtml', binding)
  end

  # add link to RSS rendering of the page
  #
  def nav_rss(link)
    link ? %{<div class="nav"><a href="#{link}">rss 1.0</a></div>} : ''
  end

  # resource list with navigation link
  #
  def list(list, nav='', foot='')
    render_template('applicationhelper_list.rhtml', binding)
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
    value = Rack::Utils.escape_html(value) if value.class == String
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

  # Add a hidden action confirmation hash to the form for CSRF protection.
  #
  def action_token_field
    if @session.member
      %{<input type="hidden" name="action_token" value="#{@request.action_token}" />}
    end
  end

  # Sort tags by name, alter font size in proportion to tag usage.
  #
  def tag_cloud
    data = Tag.find_tags(site)
    return '' if data.empty?
    max_usage = data.first[:nrelated_with_subtags]
    return '' unless max_usage > 0

    tags = data.collect {|tag|
      [ tag[:id], tag[:nrelated_with_subtags], Tag.new(site, tag[:id]).name(@request) ] }

    render_template('applicationhelper_tag_cloud.rhtml', binding)
  end

  def tag_list(tag = nil)
    tags = Tag.find_tags(site).map {|t| t[:id] }
    if tag.kind_of?(Tag) and not tags.include?(tag.id)
      # make sure the tag we want is in the list
      tags.unshift((tag.id or tag.uriref))
    end

    tags = tags.collect {|t|
      [ t, Tag.new(site, t).name(@request) ]
    }.sort_by {|t, name|
      name.downcase
    }
  end

  # render link to resource with a tooltip
  #
  # _title_ should be HTML-escaped
  #
  def resource_href(id, title = Resource.new(@request, id).title)
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
    render_template('applicationhelper_resource.rhtml', binding)
  end

  # Wrap a page around a ResourceList.
  #
  def list_page(title, list_class)
    @feeds.delete_if {|t, l| t != title }
    list = list_class.new(@request)

    @title = title + page_number(list.page)
    @content_for_layout = render_template('applicationhelper_list_page.rhtml', binding)
  end

  # Render an RSS feed page. Pass it a block that sets channel title,
  # description, and link, and returns a list of ids of resources to be
  # included in the feed.
  #
  def feed_page(cache_key)
    @request.headers['Content-Type'] = 'application/xml'
    @layout = nil

    @content_for_layout = cache.fetch_or_add(
      File.join('rss', @request.base, cache_key, @request.accept_language.join(':'))) do

      require 'rss/maker'
      RSS::Maker.make("1.0") {|maker|
        dataset = yield maker
        dataset.first.collect do |row|
          Resource.new(@request, row[dataset.key]).rss(maker)
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

  def render_template(template, b=nil)
    b ||= binding
    View.cached(@request.site, template).render(b)
  end
end
