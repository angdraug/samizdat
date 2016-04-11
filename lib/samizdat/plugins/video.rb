# Samizdat HTML5 video renderer plugin
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

class VideoPlugin < ContentFilePlugin
  register_as 'video'

  def match?(format)
    ['video/ogg', 'video/mp4', 'video/webm'].include?(format)
  end

  def render(request, mode, content)
    href = content.file.href

    if :full == mode
      %{<video src="#{href}" controls="">
      <p>} +
        _('You need a browser that supports video tag to see this content.') +
      %{</p>
      </video>
      <p>} + download_link(href, content, 'image') + '</p>'

    else
      %{<p><a href="#{content.id}">} + _("View the clip online") +
        '</a></p><p>' + download_link(href, content) + '</p>'
    end
  end
end
