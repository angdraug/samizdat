# Samizdat blog route rewriter plugin
#
#   Copyright (c) 2002-2011  Dmitry Borodaenko <angdraug@debian.org>
#
#   This program is free software.
#   You can distribute/modify this program under the terms of
#   the GNU General Public License version 3 or later.
#
# vim: et sw=2 sts=2 ts=8 tw=0

require 'samizdat'
require 'samizdat/plugins/route'

class BlogPlugin < RoutePlugin
  register_as 'blog'

  def rewrite(request)
    match = PATTERN.match(request.route)
    return unless match.kind_of? MatchData

    login, route = match[1, 2]
    id = db[:member].filter(:login => login).get(:id)
    return unless id

    request.route = '/resource/' + id.to_s + route.to_s
  end

  private

  PATTERN = Regexp.new(%r{\A/blog/([a-zA-Z0-9]+)(/.*)?\z}).freeze
end
