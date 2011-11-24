# Samizdat HTML5 video content renderer plugin
#
# The very basic version.
# TODO:
#  * support fallback flash version for video
#  * better guess real type of ogg file from mime types of parts
#
#   Copyright (c) 2002-2009  Dmitry Borodaenko <angdraug@debian.org>
#
#   This program is free software.
#   You can distribute/modify this program under the terms of
#   the GNU General Public License version 3 or later.
#
# vim: et sw=2 sts=2 ts=8 tw=0

require 'samizdat'
require 'samizdat/plugins/content_file'

class HTML5MediaPlugin < ContentFilePlugin
  AUDIO_FORMATS = %w{audio/ogg audio/webm audio/wave audio/wav audio/x-wav audio/x-pn-wav}
  VIDEO_FORMATS = %w{video/ogg video/webm application/ogg}

  def match?(format)
    AUDIO_FORMATS.include?(format) or VIDEO_FORMATS.include?(format)
  end

  def render(request, mode, content)
    href = content.file.href

    if VIDEO_FORMATS.include?(content.format)
    # it's video file
      if :full == mode
        poster  = ""
        sources = [ [ content.file.href, fix_ogg(content.format) ] ]
        msg = Message.cached(site, content.id).parts
        if msg and not msg.empty?
          msg.each do |part|
            part = Content.new(site, part)
            if part.format =~ %r{^image/}
              poster = part.file.href
            elsif match? part.format
              sources.push [ part.file.href, fix_ogg(part.format) ]
            elsif part.format =~ %r{^video/}
            # TODO: flowplayer fallback
            end
          end
        end
        sources = sources.map {|src, type| %{<source src="#{src}" type="#{type}" />} }.join("\n")

        %{<video controls="controls" poster="#{poster}">\n} +
        sources + "\n<p>" +
        _("Your browser doesn't support <code>video</code> tag.") +
         '</p></video>' +
        '<p>' + download_link(href, content, 'image') + '</p>'

      else
        %{<p><a href="#{content.id}">} + _("View the clip online") +
        '</a></p><p>' + download_link(href, content) + '</p>'
      end
    else
    # it's audio file
      if :full == mode
        %{<audio src="#{href}" controls="controls">} +
        _("Your browser doesn't support <code>audio</code> tag.") +
        '</audio><p>' + download_link(href, content, 'image') + '</p>'
      else
        %{<p><a href="#{content.id}">} + _('Listen the record online') +
        '</a></p><p>' + download_link(href, content) + '</p>'
      end
    end
  end

  private

  def fix_ogg(format)
    # mostly unneded, but better to have it
    format == 'application/ogg' ? 'video/ogg' : format
  end

end

PluginClasses.instance['html5media'] = HTML5MediaPlugin
