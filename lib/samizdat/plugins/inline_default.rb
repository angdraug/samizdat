# Samizdat default text renderer plugin
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

class TextDefaultPlugin < ContentInlinePlugin
  register_as 'inline_default'

  def default?
    true
  end

  def render(request, mode, body)
    Rack::Utils.escape_html(body).split(/^\s*$/).collect {|p|
      '<p>' + p.gsub(URI::ABS_URI_REF) {|url|
        scheme, host = $1, $4   # see URI::REGEXP::PATTERN::X_ABS_URI
        if AUTOURL_SCHEMES.include?(scheme) and not host.nil?
          url =~ /\A(.*?)([.,;:?!()]+)?\z/   # don't grab punctuation
          url, tail = $1, $2
          %{<a href="#{url}">#{url}</a>#{tail}}
        else
          url
        end
      } + "</p>\n"
    }.join
  end

  def format_name
    _('Default')
  end

  private

  AUTOURL_SCHEMES = %w[http https ftp]
end
