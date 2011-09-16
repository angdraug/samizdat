# Samizdat data content plugin superclass
#
#   Copyright (c) 2002-2009  Dmitry Borodaenko <angdraug@debian.org>
#
#   This program is free software.
#   You can distribute/modify this program under the terms of
#   the GNU General Public License version 3 or later.
#
# vim: et sw=2 sts=2 ts=8 tw=0

require 'samizdat'

class ContentFilePlugin < Plugin
  def api
    'content_file'
  end

  def render(request, mode, content)
    ''
  end

  # Replace a reference to the content file by original_filename with a working
  # link.
  #
  def rewrite_link(request, mode, content, element)
    attribute_name = LINK_ATTRIBUTE[element.name]
    element.attributes[attribute_name] = content.file.href if attribute_name
  end

  # invoked when new content file is uploaded
  #
  def new_file(file)
  end

  # invoked when content file is moved to a new id
  #
  def move_file(file, new_id)
  end

  # invoked when content file is deleted
  #
  def delete_file(file)
  end

  private

  def download_link(href, content, tag_class = nil)
    size = content.file.size
    size &&= ' (' + display_file_size(size) + ')'

    tag_class &&= %{ class="#{tag_class}"}

    %{<a#{tag_class} href="#{href}">} +
      sprintf(_('Download %s file'), file_extension(content.format)) +
      size.to_s + '</a>'
  end
end
