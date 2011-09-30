# Samizdat message content model
#
#   Copyright (c) 2002-2011  Dmitry Borodaenko <angdraug@debian.org>
#
#   This program is free software.
#   You can distribute/modify this program under the terms of
#   the GNU General Public License version 3 or later.
#
# vim: et sw=2 sts=2 ts=8 tw=0

require 'samizdat'
require 'whitewash'
require 'fileutils'
require 'magic'

class Content
  include SiteHelper

  # Usage:
  #
  #   Content.new(site, message)
  #
  #   Content.new(site, id, login)
  #
  #   Content.new(site, id, login, title)
  #
  def initialize(site, id, login = nil, title = nil)
    @site = site

    if id.kind_of?(Message)
      message = id
      id = message.id
      login ||= message.creator.login

      @parts = {}
      message.parts.each do |part|
        file = part.content.file
        if file.kind_of? ContentFile
          @parts[file.original_filename] = part.content
        end
      end
    end

    @id = id.kind_of?(Integer) ? id : nil
    @login = login

    if @id.kind_of? Integer
      title ||= rdf.get_property(@id, 'dc::title')
      format = rdf.get_property(@id, 'dc::format')

      if title.nil?
        message ||= Message.cached(site, @id)
        if message.part_of
          title = Message.cached(site, message.part_of).content.title
        end
      end
    end

    @title = title
    self.format = format   # also sets @inline and @cacheable

    if @id.kind_of? Integer
      r = rdf.fetch(
        %q{SELECT ?content, ?full, ?short
        WHERE (s::id :id ?id)
        OPTIONAL (s::content :id ?content)
                 (s::htmlFull :id ?full)
                 (s::htmlShort :id ?short)
        }, :id => @id).first

      self.body = r[:content]

      if cacheable? and r[:full]
        @html_cache = HtmlCache.new(r[:full], r[:short])
      end
    end

    @file = ContentFile.new(site, self) unless inline?
  end

  # set content id, move file to new id if necessary
  #
  def id=(id)
    @id = id
    @file.id = id if @file.kind_of?(ContentFile)
  end

  attr_reader :id, :login, :title, :format, :plugin

  # store checks for format, inline?, cacheable?, plugin
  #
  def format=(format)
    # todo: encapsulate MIME type, extension, format name, rendering type, and
    # validation in ContentFormat class
    @format = @site.validate_format(format) unless format.nil?

    @inline = (:inline == format_type(@format))
    @cacheable = (@inline and @format != 'application/x-squish')

    @plugin = site.plugins.find(plugin_api, @format)

    @file = nil if @inline
  end

  def plugin_api
    @inline ? 'content_inline' : 'content_file'
  end

  # true if content is rendered by Samizdat and not linked to a file
  #
  def inline?
    @inline
  end

  # HTML rendering of all inline messages except RDF queries is cached in
  # database (which implies that it doesn't depend on Resource object)
  #
  def cacheable?
    @cacheable
  end

  # content body (+nil+ or original_filename if not inline)
  attr_reader :body

  # Set inline message body. Forces Unix newlines, unsets HtmlCache.
  #
  def body=(body)
    @html_cache = nil
    @body = body.kind_of?(String) ? body.gsub(/\r\n/, "\n") : nil
  end

  # format content using matching content rendering plugin
  #
  def render(request, mode, body = nil)
    return '' if (inline? and body.nil? and @body.nil?) or @plugin.nil?
    return @html_cache[mode] if @html_cache and body.nil?

    body ||= @body

    case @plugin.api
    when 'content_inline'
      body = @plugin.cut(mode, body)
      html = @plugin.render(request, mode, body)

      begin
        if @plugin.safe_html?
          html

        elsif @parts and not @parts.empty?
          site.whitewash.sanitize(html) do |element|
            attribute_name = LINK_ATTRIBUTE[element.name] or next
            attribute = element.attribute(attribute_name) or next
            part = @parts[attribute.value] or next

            plugin = site.plugins.find('content_file', part.format)
            plugin.rewrite_link(request, mode, part, element)
          end

        else
          site.whitewash.sanitize(html)
        end

      rescue WhitewashError => e
        raise UserError, CGI.escapeHTML(e.message).untaint
      end

    when 'content_file'
      @plugin.render(request, mode, self)
    end
  end

  # Update HtmlCache for a message (running inside transaction is assumed).
  #
  def update_html(request = nil)
    return unless @id.kind_of? Integer

    @html_cache = nil
    fields = {:html_full => nil, :html_short => nil}

    if cacheable?
      @html_cache = HtmlCache.new(
        render(request, :full),
        render(request, :short))
      fields[:html_full] = @html_cache[:full]
      if @html_cache[:short] != @html_cache[:full]
        fields[:html_short] = @html_cache[:short]
      end
    end

    db[:message][:id => @id] = fields
  end

  # Re-render HtmlCache for a single message.
  #
  # Command line example:
  #
  #   ruby -r samizdat -e 'DRb.start_service; Content.regenerate_html(Site.new("samizdat"), 1)'
  #
  def Content.regenerate_html(site, id)
    # fixme: update_html needs a Request object
    site.db.transaction { Message.cached(site, id).content.update_html }
  end

  # Re-render HtmlCache for all messages. Depending on the size of your site,
  # this may take hours or even days, on the other hand, you don't have stop
  # the service while this method is working.
  #
  # Command line example:
  #
  #   ruby -r samizdat -e 'DRb.start_service; Content.regenerate_all_html(Site.new("samizdat"))'
  #
  def Content.regenerate_all_html(site)
    site.db[:message].filter(:content => nil).invert.select(:id).each do |m|
      Content.regenerate_html(site, m[:id])
    end
    site.cache.flush
  end

  # ContentFile object for a non-inline message
  attr_reader :file

  def file=(file)
    @file = file
    self.format = file.format
    self.body = file.original_filename
  end
end


class HtmlCache
  def initialize(full, short)
    @html_cache = {}
    @html_cache.default = @html_cache[:full] = full unless full.nil?
    @html_cache[:short] = short unless short.nil? or short == full
  end

  attr_reader :html_cache

  def [](mode)
    @html_cache[mode]
  end
end


class ContentFile
  include SiteHelper

  def ContentFile.detect_format(file)
    format =
      if file.respond_to?(:path) and file.path
        Magic.guess_file_mime_type(file.path)
      elsif file.kind_of?(StringIO)
        Magic.guess_string_mime_type(file.string)
      elsif file.kind_of?(String)
        Magic.guess_string_mime_type(file)
      end

    format.nil? and raise RuntimeError,
      _('Failed to detect content type of the uploaded file')

    format
  end

  def initialize(site, content)
    @site = site
    @id = content.id
    @login = content.login
    @format = content.format
    @original_filename = content.body
    @plugin = content.plugin
  end

  attr_reader :id, :login, :format, :original_filename

  def extension
    file_extension(@format)
  end

  # relative path to file holding multimedia message content
  #
  def location(id = @id)
    validate_id(id)

    # security: keep format and creator login controlled (see untaint in
    # path())
    # todo: subdirectories
    File.join(@login, id.to_s + '.' + extension)
  end

  # multimedia message content filename
  #
  def path(id = @id)
    File.join(site.content_dir, location(id).untaint)
  end

  def href
    File.join((config['site']['content_base'] or ''), location)
  end

  def size
    File.size(path) if exists?
  end

  def exists?
    File.exists?(path)
  end

  # move content file to a new id
  #
  def id=(id)
    validate_id(id)

    File.rename(path, path(id))
    @plugin.move_file(self, id)

    @id = id
  end

  def delete
    File.delete(path)
    @plugin.delete_file(self)
  end

  private

  def validate_id(id)
    Model.validate_id(id) or raise RuntimeError,
      "Unexpected file upload id (#{id.inspect})"
  end
end


class ContentFilePendingUpload < ContentFile
  def initialize(site, content, upload, part, format, original_filename)
    @site = site

    site.upload_enabled? or raise UserError,
      _('Multimedia upload is disabled on this site')

    @id = nil
    @login = content.login
    @original_filename = original_filename

    begin
      @format = site.validate_format(format)
    rescue UnknownFormatError
      raise RuntimeError, 'Pending upload with unsupported file format detected'
    end

    @plugin = site.plugins.find('content_file', @format)

    @upload_path = upload.path
    @part = part
  end

  # A content file without _id_ is stored under pending uploads
  # directory (PendingUpload#path). When _id_ is provided, the method will
  # return a normal location under content directory, same as
  # ContentFile#location.
  #
  def location(id = nil)
    id ? super(id) :
      File.join(@upload_path,
                (@part ? 'part_' + @part.to_s : 'upload') + '.' + extension)
  end

  # This is only needed to override default id parameter value from @id to
  # +nil+.
  #
  # fixme: this is an obscure and fragile hack
  #
  def path(id = nil)
    super(id)
  end
end


class ContentFileNewUpload < ContentFilePendingUpload
  def initialize(site, content, upload, part, file)
    super(site, content, upload, part,
          ContentFile.detect_format(file),
          file.original_filename.sub(%r{\A.*(?:/|\\)}, ''))

    save(file)
  end

  private

  def mkdir(dir)
    File.exists?(dir) or FileUtils.mkdir_p(dir)
  end

  def save(file)
    destination = self.path
    mkdir(File.dirname(destination))

    case file
    when File, Tempfile   # copy large files directly
      FileUtils.cp(file.path, destination)
    when StringIO
      File.open(destination, 'w') {|f| f.write(file.read) }
    when ContentFile
      begin
        FileUtils.ln(file.path, destination)
      rescue Errno::EXDEV
        FileUtils.cp(file.path, destination)
      end
    else
      raise RuntimeError, "Unexpected file class '#{file.class}'"
    end

    @plugin.new_file(self)
  end
end


class PendingUpload
  include SiteHelper

  # Create new pending upload record for _login_, register _content_ and/or
  # _parts_ as uploaded files.
  #
  def PendingUpload.create(site, login, file, parts)
    PendingUpload.new(site, nil, login, file, parts)
  end

  def initialize(site, id, login = nil, file = nil, parts = nil)
    @site = site

    if @id = Model.validate_id(id)
      load_from_db
    else
      register(login, file, parts)
    end
  end

  attr_reader :file, :parts

  def to_i
    @id
  end

  def to_s
    @id.to_s
  end

  # Pending uploads are stored under upload/ subdirectory of the user's content
  # directory.
  #
  def path
    File.join(@login, 'pending', @id.to_s)
  end

  # Run inside transacton.
  #
  def status=(status)
    if ['confirmed', 'expired'].include?(status)
      # remove associated files and directories

      ([ @file ] + @parts).compact.each do |file|
        file.delete if file.exists?
      end

      # fixme: this will fail if there's unexpected garbage left in pending
      # upload directory after all known files were deleted
      dir = File.join(site.content_dir, path.untaint)
      FileUtils.rmdir(dir) if File.exists?(dir) and File.directory?(dir)
    end
    db[:pending_upload][:id => @id] = {:status => status}
  end

  private

  def load_from_db
    @login = db[:pending_upload].filter(:id => @id).get(:login)
    @login or raise ResourceNotFoundError, 'PendingUpload ' + @id.to_s

    @parts = []
    db[:pending_upload_file].filter(:upload => @id).each do |f|
      content_file = ContentFilePendingUpload.new(
        site, Content.new(site, nil, @login), self,
        f[:part], f[:format], f[:original_filename])

      if f[:part]
        @parts[ f[:part] ] = content_file
      else
        @file = content_file
      end
    end
  end

  def register(login, file, parts)
    @login = login

    db.transaction do
      check_queue
      insert
      if file
        @file = add_file(file)
      end
      if parts.kind_of?(Enumerable)
        @parts = []
        parts.each_with_index {|part, i| @parts[i] = add_file(part, i) }
      end
    end
  end

  # Check if there's room in upload queue for this user. If queue is full,
  # expire oldest pending upload to free up room in the queue.
  #
  # Run inside transacton.
  #
  def check_queue
    timeout = (config['timeout']['pending_upload'] or 4 * 60 * 60)
    queue_limit = (config['limit']['pending_upload_queue_size'] or 3)

    pending = db[:pending_upload].filter(:login => @login, :status => 'pending')

    pending.filter(
      %q{created_date < CURRENT_TIMESTAMP - ? * INTERVAL '1 seconds'}, timeout
    ).select(:id).each do |u|
      PendingUpload.new(site, u[:id]).status = 'expired'
    end

    if pending.count >= queue_limit
      id = pending.order(:id).get(:id)
      PendingUpload.new(site, id).status = 'expired'
    end
  end

  def insert
    @id = db[:pending_upload].insert(:login => @login)
  end

  def add_file(file, part = nil)
    content_file = ContentFileNewUpload.new(
      site, Content.new(site, nil, @login), self, part, file)

    db[:pending_upload_file].insert(
      :upload => @id,
      :part => part,
      :format => content_file.format,
      :original_filename => content_file.original_filename
    )

    content_file
  end
end
