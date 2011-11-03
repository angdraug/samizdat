# Samizdat text content plugin superclass
#
#   Copyright (c) 2002-2011  Dmitry Borodaenko <angdraug@debian.org>
#
#   This program is free software.
#   You can distribute/modify this program under the terms of
#   the GNU General Public License version 3 or later.
#
# vim: et sw=2 sts=2 ts=8 tw=0

require 'samizdat'

class ContentInlinePlugin < Plugin
  def initialize(site, options)
    super

    @cut_pattern = Regexp.new(
      /\A(.*?)#{Regexp.escape((options['cut_mark'] or CUT_MARK_DEFAULT))}/m
    ).freeze
  end

  def api
    'content_inline'
  end

  def render(request, mode, body)
    ''
  end

  def format_name
    ''
  end

  def safe_html?
    false
  end

  def cut(mode, body)
    case mode
    when :short
      cut_match = @cut_pattern.match(body)
      short = limit_string(body, config['limit']['short'])

      if cut_match and cut_match[1].size < short.size
        cut_match[1]
      else
        short
      end
    else
      body.sub(@cut_pattern, @options['exclude_cut_from_full'] ? '' : '\1')
    end
  end

  private

  CUT_MARK_DEFAULT = '$$$'
end
