# Samizdat image renderer plugin
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
require 'fileutils'
require 'nokogiri'

# don't allow RMagic to second-guess ld.so
RMAGICK_BYPASS_VERSION_TEST = true
require 'RMagick'

class ImagePlugin < ContentFilePlugin
  include Magick

  register_as 'image'

  def match?(format)
    :image == format_type(format)
  end

  def render(request, mode, content)
    title = Rack::Utils.escape_html(content.title.to_s)
    image_href = content.file.href

    if version_exists?(content.file, mode)
      link =
        case mode
        when :full
          image_href
        when :short
          content.id.kind_of?(Integer) ? content.id.to_s : image_href
        end

      image_href = version_path(content.file, image_href, mode)
    end

    html = %{<img alt="#{title}" src="#{image_href}" />}

    if link
      html = %{<a class="image" href="#{link}">#{html}<div>} + _('Click to enlarge') + '</div></a>'
    end

    html
  end

  def rewrite_link(request, mode, content, element)
    if 'img' != element.name or %r{/a\b}.match(element.path)
      super

    else   # <img/> that is not wrapped inside <a/>
      lang = (
        (content.id and Message.cached(site, content.id).lang) or
        request['lang'] or request.language)
      html = request.temporary_language(lang) { render(request, mode, content) }

      n = Nokogiri::HTML.fragment(html) {|config| config.noblanks }
      n = n.children.first
      element.attribute_nodes.each do |attribute|
        n[attribute.name] ||= attribute.value
      end

      element.replace(n)
    end
  end

  def new_file(file)
    return if versions.empty?   # nothing to generate

    begin
      original = ImageList.new(file.path)
    rescue ImageMagickError
      return   # don't generate versions if ImageMagick can't handle this file
    end

    versions.each do |version|
      limit = @options[version].to_i
      next unless limit > 0 and
        (original.columns > limit or original.rows > limit)

      scale = limit.to_f / [ original.columns, original.rows ].max
      original.copy.resize(scale).write(version_path(file, file.path, version))
    end
  end

  def move_file(file, new_id)
    each_version(file) do |version|
      destination = version_path(file, file.path(new_id), version)

      File.exists?(File.dirname(destination)) or
        FileUtils.mkdir_p(File.dirname(destination))

      File.rename(version_path(file, file.path, version), destination)
    end
  end

  def delete_file(file)
    each_version(file) do |version|
      File.delete(version_path(file, file.path, version))
    end
  end

  private

  VERSION_NAME_PATTERN = Regexp.new(/\A[[:alnum:]_]+\z/).freeze

  def versions
    @options.kind_of?(Hash) ? @options.keys.grep(VERSION_NAME_PATTERN) : []
  end

  def version_path(file, path, version)
    ext = file.extension
    path.sub(%r{\.#{ext}\z}, '.' + version.to_s + '.' + ext)
  end

  def version_exists?(file, version)
    File.exists?(version_path(file, file.path, version))
  end

  def each_version(file)
    versions.each do |version|
      yield(version) if version_exists?(file, version)
    end
  end
end
