# Samizdat route rewriter plugin superclass
#
#   Copyright (c) 2002-2009  Dmitry Borodaenko <angdraug@debian.org>
#
#   This program is free software.
#   You can distribute/modify this program under the terms of
#   the GNU General Public License version 3 or later.
#
# vim: et sw=2 sts=2 ts=8 tw=0

require 'samizdat'

class RoutePlugin < Plugin
  def api
    'route'
  end

  # Matching and rewriting usually apply the same regexp, to avoid it being
  # applied twice, all route plugins match automatically, and the decision
  # whether to rewrite the route is made in #rewrite().
  #
  def match?(request)
    true
  end

  def rewrite(request)
  end
end
