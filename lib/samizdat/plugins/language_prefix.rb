# Samizdat language prefix route rewriter plugin
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

# Make sure this plugin is at the head of the route rewriting chain.
#
class LanguagePrefixPlugin < RoutePlugin
  register_as 'language_prefix'

  def rewrite(request)
    match = PATTERN.match(request.route)
    return unless match.kind_of? MatchData

    language, route = match[1, 2]
    return unless config['locale']['languages'].include?(language)

    request.language = language
    request.route = route
  end

  private

  PATTERN = Regexp.new(%r{\A/([a-zA-Z0-9_.@]+)(/.*)\z}).freeze
end
