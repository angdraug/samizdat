# Samizdat material item exchange
#
#   Copyright (c) 2002-2009  Dmitry Borodaenko <angdraug@debian.org>
#
#   This program is free software.
#   You can distribute/modify this program under the terms of
#   the GNU General Public License version 3 or later.
#
# vim: et sw=2 sts=2 ts=8 tw=0

class ItemController < Controller
  def index
    @title = _('Not Implemented')
    @content_for_layout = box(@title, '<p>' + _('Material item exchange is not implemented yet.') + '</p>')
  end
end
