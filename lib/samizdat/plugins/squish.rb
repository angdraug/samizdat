# Samizdat Squish query renderer plugin
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
require 'samizdat/helpers/application_helper'

class SquishPluginHelper
  include ApplicationHelper

  def initialize(request)
    self.request = request
  end
end

class SquishPlugin < ContentInlinePlugin
  register_as 'squish'

  def match?(format)
    'application/x-squish' == format
  end

  def render(request, mode, body)
    # inline query form
    SquishPluginHelper.new(request).form('query/run',
      [:textarea, 'q', body.to_s],
      [:br], [:submit, 'run', _('Run')])
  end

  def format_name
    _('Squish query')
  end

  def safe_html?
    true
  end
end
