# Samizdat Textile formatted text renderer plugin
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

begin
  require 'redcloth'

  # get rid of <del>, '-' belongs to text, not markup
  if defined?(RedCloth::QTAGS)
    RedCloth::QTAGS.delete_if {|rc, ht, re, rtype| 'del' == ht }
  elsif defined?(RedCloth::Formatters::HTML)
    module RedCloth::Formatters::HTML
      def del(opts)
        opts[:text]
      end
    end
  end

rescue LoadError
  class RedCloth < String
    def to_html   # revert to text/plain
      "<pre>#{Rack::Utils.escape_html(self)}</pre>"
    end
  end
end

class TextilePlugin < ContentInlinePlugin
  register_as 'textile'

  def match?(format)
    'text/textile' == format
  end

  def render(request, mode, body)
    RedCloth.new(body).to_html
  end

  def format_name
    'Textile'
  end
end
