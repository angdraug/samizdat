# Samizdat feed syndication helpers
#
#   Copyright (c) 2002-2011  Dmitry Borodaenko <angdraug@debian.org>
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
    feeds = []
    each_import_feed do |feed_name, url, limit|
      feed = shared_cache['samizdat/*/import_feeds/' + url]   # '*' to avoid clashes with site_name

      if feed.kind_of? Array and feed.size > 0
        feeds.push(feed[0, limit], feed_name)
      end
    end

    render_template('syndicationhelper_render_feeds.rhtml', binding)
  end
end
