# Samizdat Flowplayer playable content renderer plugin
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

class FlowplayerPlugin < ContentFilePlugin
  register_as 'flowplayer'

  def match?(format)
    ['video/x-flv', 'video/mp4'].include?(format)
  end

  def render(request, mode, content)
    id = "id#{content.id}object"
    href = content.file.href

    if :full == mode
      %{<div id="#{id}" class="flowplayer">} +
        _('Install a Flash plugin and enable JavaScript to see this content.') +
      %{</div>
      <script type="text/javascript">
        flashembed("#{id}",
          { src: '#{@options['src']}', bgcolor: '#{@options['bgcolor']}' },
          { config:
            { clip: { url: '#{href}', scaling: 'orig', autoPlay: false } } });
      </script>} + download_link(href, content, 'image')

    else
      %{<p><a href="#{content.id}">} + _("View the clip online") +
        '</a></p><p>' + download_link(href, content) + '</p>'
    end
  end
end
