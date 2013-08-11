# Samizdat limited HTML text renderer plugin
#
#   Copyright (c) 2002-2011  Dmitry Borodaenko <angdraug@debian.org>
#
#   This program is free software.
#   You can distribute/modify this program under the terms of
#   the GNU General Public License version 3 or later.
#
# vim: et sw=2 sts=2 ts=8 tw=0

require 'samizdat'
require 'samizdat/plugins/content_inline'

class HtmlPlugin < ContentInlinePlugin
  register_as 'html'

  def match?(format)
    'text/html' == format
  end

  def render(request, mode, body)
    '<div>' + body + '</div>'
  end

  def format_name
    'HTML'
  end
end
