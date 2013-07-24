# Samizdat Flash renderer plugin
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

class FlashPlugin < ContentFilePlugin
  register_as 'flash'

  def match?(format)
    'application/x-shockwave-flash' == format
  end

  def render(request, mode, content)
    id = "id#{content.id}object"
    href = content.file.href

    %{<div id="#{id}">} +
      _('Install a Flash plugin and enable JavaScript to see this content.') +
    %{</div>
    <script type="text/javascript">
      flashembed("#{id}", { src: '#{href}', bgcolor: '#000' });
    </script>} + download_link(href, content, 'image')
  end
end
