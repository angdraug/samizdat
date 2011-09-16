# Samizdat verbatim plain text renderer plugin
#
#   Copyright (c) 2002-2009  Dmitry Borodaenko <angdraug@debian.org>
#
#   This program is free software.
#   You can distribute/modify this program under the terms of
#   the GNU General Public License version 3 or later.
#
# vim: et sw=2 sts=2 ts=8 tw=0

require 'samizdat'
require 'samizdat/plugins/content_inline'

class PlainTextPlugin < ContentInlinePlugin
  def match?(format)
    'text/plain' == format
  end

  def render(request, mode, body)
    "<pre>#{CGI.escapeHTML(body)}</pre>"
  end

  def format_name
    _('Verbatim plain text')
  end
end

PluginClasses.instance['plain_text'] = PlainTextPlugin
