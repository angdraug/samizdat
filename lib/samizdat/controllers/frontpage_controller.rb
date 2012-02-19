# Samizdat front page
#
#   Copyright (c) 2002-2011  Dmitry Borodaenko <angdraug@debian.org>
#
#   This program is free software.
#   You can distribute/modify this program under the terms of
#   the GNU General Public License version 3 or later.
#
# vim: et sw=2 sts=2 ts=8 tw=0

require 'samizdat/helpers/syndication_helper'

class FrontpageController < Controller
  include SyndicationHelper

  def initialize(request, id = nil)
    super

    @feeds.update(
      _('Features') => 'frontpage/rss',
      _('Recent Updates') => 'frontpage/rss?feed=updates'
    )
  end

  def index
    @title = config['site']['name']

    key = %{index/#{'yes' != @request.cookie('nostatic')}}
    if config['locale']['allow_monolanguage']
      key << '/' << ('yes' != @request.cookie('monolanguage')).to_s
    end
    return if try_cache(key)

    # links
    @all_replies_query = Rack::Utils.escape('SELECT ?resource WHERE (dc::date ?resource ?date) (s::inReplyTo ?resource ?parent) ORDER BY ?date DESC')
    @more_links = render_more_links
    @imported_feeds = render_feeds

    # static parts
    @language_list = language_list
    @header = static_text('header')
    @footer = static_text('footer')

    @template = 'frontpage_index.rhtml'
  end

  def features
    list_page(_('Features'), FeaturesList)
  end

  def updates
    list_page(_('Recent Updates'), UpdatesList)
  end

  # RSS feed of features or updates
  #
  def rss
    feed = @request['feed']
    case feed
    when 'updates'
      feed_title = _('Recent Updates')
    else
      feed = 'features'
      feed_title = _('Features')
    end

    feed_page('frontpage/' + feed) do |maker|
      maker.channel.title = config['site']['name'] + ': ' + feed_title
      maker.channel.description = strip_tags(static_text('header'))
      maker.channel.link = @request.base

      case feed
      when 'updates'
        UpdatesList.new(@request).dataset
      else
        FeaturesList.new(@request, limit_page).dataset
      end
    end
  end

  private

  # do Apache's job and include files in static headers
  #
  def gsub_ssi_file(static)
    return '' unless static.kind_of? String
    static.gsub(/<!--#include\s+file="([^"]+)"\s*-->/i) do
      name = $1
      name = File.join(@request.document_root, @request.uri_prefix, name) unless
        File::SEPARATOR == name[0, 1]

      File.open(name) {|f| f.read }
    end
  end

  # read from config and translate static header or footer
  #
  def static_text(name)
    return '' if 'yes' == @request.cookie('nostatic')

    text = config['site'][name]
    text = (
      text[@request.language] or
      text[default_language] or
      text.to_a[0][1]
    ) if text.kind_of? Hash
    text = gsub_ssi_file(text)

    (text =~ /[^\s]/) ? text : ''
  end

  # language selection
  #
  def language_list
    return '' if
      'yes' == @request.cookie('nostatic') or
      not (defined?(FastGettext) or defined?(GetText)) or
      config['locale']['languages'].size <= 1

    languages = config['locale']['languages']
    languages = languages.sort if config['locale']['sort_languages']

    render_template('frontpage_language_list.rhtml', binding)
  end

  def render_more_links
    id = Model.validate_id(config['site']['more_links'])
    return '' unless id

    begin
      message = Message.cached(site, id).select_translation(@request.accept_language)
      message.content.render(@request, :full)
    rescue ResourceNotFoundError
      ''
    end
  end
end
