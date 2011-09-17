# Samizdat view management class
#
#   Copyright (c) 2002-2011  Dmitry Borodaenko <angdraug@debian.org>
#
#   This program is free software.
#   You can distribute/modify this program under the terms of
#   the GNU General Public License version 3 or later.
#
# vim: et sw=2 sts=2 ts=8 tw=0

require 'samizdat'
require 'erb'

class View
  def initialize(site, template)
    location = find_file(template, site.config['templates'])
    location or raise RuntimeError,
      "Template not found: '#{Rack::Utils.escape_html(template)}'"
    set_renderer(location)
  end

  def render(binding)
    @erb.result(binding)
  end

  # returns a cached View object
  #
  def View.cached(site, template)
    site.local_cache.fetch_or_add('template/' + template) do
      View.new(site, template)
    end
  end

  private

  def set_renderer(location)
    body = File.open(location) {|f| f.read }
    @erb = ERB.new(body.untaint, nil, '>')
  end
end
