# Samizdat feed syndication helpers
#
#   Copyright (c) 2002-2009  Dmitry Borodaenko <angdraug@debian.org>
#
#   This program is free software.
#   You can distribute/modify this program under the terms of
#   the GNU General Public License version 3 or later.
#
# vim: et sw=2 sts=2 ts=8 tw=0

require 'samizdat/helpers/application_helper'

module SyndicationHelper
  include ApplicationHelper

  def each_import_feed
    feeds = config['import_feeds']
    if feeds.kind_of? Hash
      feeds.keys.sort.each do |name|
        options = feeds[name]
        case options
        when Hash
          url = options['url']
          limit = options['limit']
        when String
          url = options
        end
        limit ||= limit_page
        next unless url.kind_of? String   # ignore malformed config
        yield name, url, limit
      end
    end
  end

  def render_feeds
    output = ''

    each_import_feed do |feed_name, url, limit|
      feed = shared_cache['samizdat/*/import_feeds/' + url]   # '*' to avoid clashes with site_name

      if feed.kind_of? Array and feed.size > 0
        output << %{<div class="feed"><div class="feed-name">#{feed_name}</div>\n<ul>}
        feed[0, limit].each do |item|
          output << %{<li><a href="#{item['link']}" title="#{format_date(item['date'])}">#{item['title']}</a></li>\n}
        end
        output << %{</ul></div>\n}
      end
    end

    output
  end
end
