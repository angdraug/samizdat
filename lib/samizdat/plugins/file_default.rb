# Samizdat default file renderer plugin
#
#   Copyright (c) 2002-2011  Dmitry Borodaenko <angdraug@debian.org>
#
#   This program is free software.
#   You can distribute/modify this program under the terms of
#   the GNU General Public License version 3 or later.
#
# vim: et sw=2 sts=2 ts=8 tw=0

require 'samizdat'
require 'samizdat/plugins/content_file'

class FileDefaultPlugin < ContentFilePlugin
  register_as 'file_default'

  def default?
    true
  end

  def render(request, mode, content)
    '<p>' + download_link(content.file.href, content) + '</p>'
  end
end
