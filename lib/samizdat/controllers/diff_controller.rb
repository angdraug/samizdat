# Samizdat message difference engine
#
#   Copyright (c) 2002-2011  Dmitry Borodaenko <angdraug@debian.org>
#
#   This program is free software.
#   You can distribute/modify this program under the terms of
#   the GNU General Public License version 3 or later.
#
# vim: et sw=2 sts=2 ts=8 tw=0

require 'samizdat/helpers/diff_helper'

class DiffController < Controller
  include DiffHelper

  def index
    old = Message.cached(site, @request['old'].to_i)
    new = Message.cached(site, @request['new'].to_i)

    (old.kind_of?(Message) and new.kind_of?(Message)) or raise UserError,
      _('Bad input')

    @title = _('Message') + ' / ' + Resource.new(@request, new.id).title +
      ' / ' + _('Changes')

    @content_for_layout = render_diff(old, new)
  end
end
