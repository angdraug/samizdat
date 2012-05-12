# Samizdat message controller
#
#   Copyright (c) 2002-2011  Dmitry Borodaenko <angdraug@debian.org>
#
#   This program is free software.
#   You can distribute/modify this program under the terms of
#   the GNU General Public License version 3 or later.
#
# vim: et sw=2 sts=2 ts=8 tw=0

require 'samizdat/helpers/message_helper'

class MessageController < Controller
  include MessageHelper

  def index
    @request.redirect('message/publish')
  end

  def source
    @message = Message.cached(site, @id)
    @title = escape_title(@message.content.title)
    @content_for_layout = render_template('message_source.rhtml', binding)
  end

  def hide
    toggle('hide', :hide!, true, _('Hide Message'),
           '<p class="moderation">' +
           _('The message will be hidden from public view.') +
           '</p>' +
           hide_message(Resource.new(@request, @id).full, true))
  end

  def unhide
    toggle('unhide', :hide!, false, _('Unhide Message'),
           '<p class="moderation">' +
           _('The message will not be hidden from public view.') +
           '</p>' +
           Resource.new(@request, @id).full)
  end

  def lock
    toggle('lock', :lock!, true, _('Lock Replies'),
           '<p class="moderation">' +
           _('Publishing of new replies to this message will be locked.') +
           '</p>' +
           Resource.new(@request, @id).full)
  end

  def unlock
    toggle('unlock', :lock!, false, _('Unlock Replies'),
           '<p class="moderation">' +
           _('Publishing of new replies to this message will be unlocked.') +
           '</p>' +
           Resource.new(@request, @id).full)
  end

  def reparent
    assert_moderate

    @message = Message.cached(site, @id)
    @message.assert_current_version

    property_map = [
      [ 's::inReplyTo', _('A reply') ],
      [ 's::isTranslationOf', _('A translation') ],
      [ 's::subTagOf', _('A sub-tag') ],
      [ 'dct::isPartOf', _('A part') ]
    ]

    new_parent, property, part_sequence_number =
      @request.values_at %w[new_parent property part_sequence_number]
    new_parent &&= normalize_reference(new_parent)
    part_sequence_number &&= part_sequence_number.to_i

    if confirm? and property_map.assoc(property)
      save('reparent') do
        @message.reparent!(new_parent, property, part_sequence_number)
      end
      @request.redirect(@message.id)
    else
      @title = _('Reparent Message')
      @content_for_layout = render_template('message_reparent.rhtml', binding)
    end
  end

  def publish
    assert_post

    @message = Message.new(site, nil)
    set_creator
    set_lang
    set_open
    set_tag
    set_parts
    set_content

    post(
      :title => _('New Message'),
      :edit_form_options => [:show_tags, :attach_parts]
    )
  end

  def reply
    assert_post

    @message = Message.new(site, nil)
    set_creator
    parent = set_parent
    set_content(parent)
    set_lang(parent.lang)
    set_open(parent.open)

    parent.may_reply? or raise UserError, _("You can't reply to this message")

    post(
      :title => _('Reply'),
      :redirect => Proc.new { location_under_parent(parent) },
      :footer => box(_('Parent Message'), Resource.new(@request, parent.id).full)
    )
  end

  def translate
    assert_post

    @message = Message.new(site, nil)
    set_creator
    original = set_translation_of
    set_content
    set_lang
    set_open(original.open)

    if (preview? or confirm?) and @message.lang == original.lang
      raise UserError, sprintf(
        _("Please select a language that is different from the language of the original message (%s)"),
        original.lang)
    end

    original_resource = Resource.new(@request, original.id)
    post(
      :title => _('Translate'),
      :footer => box(
        _('Original Message') + ': ' + original_resource.title,
        original_resource.full)
    )
  end

  def edit
    assert_post

    @message = Message.cached(site, @id)
    if @session.member.nil? or
      (@message.creator.id != @session.member and not @message.open)

      raise UserError, _('You are not allowed to edit this message')
    end
    @message.assert_current_version

    set_creator
    set_content
    set_lang(@message.lang)

    post(
      :title => _('Edit Message'),
      :edit => Proc.new { @message.edit!(@old_content) },
      :edit_form_options => [:disable_open, :lock_date]
    )
  end

  def takeover
    assert_moderate

    @message = Message.cached(site, @id)
    @message.assert_current_version

    set_content
    set_lang(@message.lang)
    set_open

    post(
      :title => _('Take Over Message'),
      :edit => Proc.new { @message.edit!(@old_content) },
      :edit_form_options => [:lock_date],
      :moderate => 'takeover',
      :header =>
        '<p class="moderation">' +
        _('Edit message content and open-for-all status, message will remain attributed to the current creator.') +
        '</p>'
    )
  end

  def replace
    assert_moderate

    @message = Message.cached(site, @id)
    set_content
    set_lang(@message.lang)
    set_open(false)

    post(
      :title => _('Replace Message'),
      :edit => Proc.new { @message.replace!(@old_content) },
      :edit_form_options => [:lock_date],
      :moderate => 'replace',
      :header =>
        '<p class="moderation">' +
        _('MESSAGE WILL BE COMPLETELY REPLACED, NO RECOVERY WILL BE POSSIBLE. PLEASE PROVIDE DETAILED JUSTIFICATION FOR THIS ACTION.') +
        '</p>'
    )
  end

  def request_moderation
    assert_post

    if confirm?
      save do
        Moderation.request!(site, @id)
      end
      @request.redirect(@id)

    else
      Moderation.check_request(site, @id)
      @title = _('Request Moderation')
      @content_for_layout = render_template('message_request_moderation.rhtml', binding)
    end
  end

  def acknowledge
    assert_moderate

    if confirm?
      save('acknowledge') { }
      @request.redirect_when_done

    else
      @request.set_redirect_when_done_cookie
      @title = _('Acknowledge Moderation Request')
      @content_for_layout = render_template('message_acknowledge.rhtml', binding)
    end
  end

  private

  # check if user is allowed to post messages
  #
  def assert_post
    @member.assert_allowed_to('post')
  end

  def preview?
    @request.has_key? 'preview'
  end

  def confirm?
    @request.has_key? 'confirm'
  end

  def post(options)
    if confirm? or preview?
      check_content
      check_date if options[:edit_form_options] and options[:edit_form_options].include?(:lock_date)

      if confirm?
        save(options[:moderate]) do
          if options[:edit]
            options[:edit].call
          else
            @message.insert!
            update_tag
          end
          update_html
        end
        @request.redirect(options[:redirect] ? options[:redirect].call : @message.id)

      else
        preview
      end

    else
      @title = options[:title]
      edit_form_options = (options[:edit_form_options] or [])
      @content_for_layout = content_for_post(
        @title, options[:header], options[:footer], action_location,
        *edit_form_options)
    end
  end

  def set_creator
    @message.creator = Member.cached(site, @session.member)
  end

  def set_parent
    parent = Message.cached(site, @id)
    parent.assert_current_version
    @message.parent = @id
    parent
  end

  def set_translation_of
    original = Message.cached(site, @id)
    original.assert_current_version
    @message.translation_of = @id
    original
  end

  def location_under_parent(parent)
    if not parent.kind_of? Message
      @message.id
    elsif parent.nreplies + 1 > limit_page
      "resource/#{parent.id}?page=#{((parent.nreplies + 1) / limit_page) + 1}#id#{@message.id}"
    else
      "#{parent.id}#id#{@message.id}"
    end
  end

  def set_content(parent = nil)
    title, format, body = @request.values_at %w[title format body]
    title = parent.content.title if title.nil? and parent

    if file = @request.value_file('file')
      format = ContentFile.detect_format(file)
      format = site.validate_format(format)
      if format and :inline == format_type(format)
        body = file.read   # transform to inline message
        file = nil
      end
    end

    if preview? and (file or @parts)
      @upload = PendingUpload.create(site, @session.login, file, @parts)
    elsif confirm? and upload_id = @request['upload']
      @upload = PendingUpload.new(site, upload_id)
    end

    if @upload and @upload.parts and not @upload.parts.empty?
      @message.parts = @upload.parts.collect {|part| part_message(part) }
    end

    if preview? and body.nil? and @upload.nil? and
      @message.id and (not @message.content.inline?) and
      title and title != @message.content.title
      # when changing title of a multimedia message, copy content file
      # from the old version

      @upload = PendingUpload.create(
        site, @session.login, @message.content.file, nil)
    end

    new_content = Content.new(site, @message, nil, title)
    new_content.format = format
    new_content.body = body
    @old_content = (@message.content or new_content)
    @message.content = new_content

    @message.content.file = @upload.file if @upload and @upload.file
  end

  def set_lang(default = nil)
    @message.lang = (@request['lang'] or default or @request.language)
  end

  # replace request base prefix in place
  #
  def normalize_reference(ref)
    if ref.kind_of?(String) and ref =~ /[^0-9]/
      ref = ref.gsub(Regexp.new('\A' + Regexp.escape(@request.base) + '(.+)\z'), '\1')
    end

    ref
  end

  def set_open(default = false)
    @message.open = @message.validate_open(
      (@request['open'] or default))
  end

  def set_tag
    @tag, = @request.values_at %w[tag]

    if @tag
      @tag = Tag.new(site, @tag, @id)

      if @tag.allowed_to_vote?(@member)
        @message.tags = [ @tag ]   # get it displayed in preview page
      else
        @tag = nil
      end
    end
  end


  # must be called before set_content
  #
  def set_parts
    @parts = @request.keys.collect {|param|
      if param =~ /\Apart_\d+\z/
        @request.value_file(param)
      end
      # todo: limit number of parts that can be uploaded in one go
    }.compact
    @parts = nil if @parts.empty?
  end

  def part_message(part)
    m = Message.new(site, nil)
    m.part_of = @message.id
    m.creator = @message.creator
    m.lang = @message.lang
    m.open = @message.open
    m.content = Content.new(site, m, nil, part.original_filename)
    m.content.file = part
    m
  end

  def check_upload
    @message.content.inline? and
      raise UserError, 'Unexpected state: inline message upload confirmed'
    @message.content.file.exists? or
      raise UserError, _('Uploaded file not found. Your upload must have expired.')
  end

  def check_content
    content = @message.content

    content.title or (@message.part_of and not @message.translation_of) or raise UserError,
      _('Message title is required for a new message')

    site.plugins.find_all('spam', :add_message_fields, :check_message_fields) do |plugin|
      plugin.check_message_fields(@request)
    end

    if content.inline? and content.body.kind_of? String
      site.plugins.find_all('spam', :check_text) do |plugin|
        plugin.check_text(@request.role, content.title.to_s + "\n\n" + content.body)
      end

    elsif @upload
      check_upload

    else
      raise UserError, _('Message body is required')
    end
  end

  def check_date
    date = @request['date'].to_i
    if date > 0 and @message.date.respond_to?(:to_time) and
      @message.date.to_time.to_i > date

      raise UserError,
        _(%q{This message was modified after you started to edit it, check the latest version to make sure you don't overwrite any recent changes})
    end
  end

  def toggle(action, method, value, title, message)
    assert_moderate

    @message = Message.cached(site, @id)
    @message.assert_current_version

    if confirm?
      save(action) do
        @message.send(method, value)
      end
      @request.redirect(@id)
    else
      @title = title
      @content_for_layout = render_template('message_toggle.rhtml', binding)
    end
  end

  def content_for_post(title, header, footer, action, *options)
    old_title = @old_content.title

    old_body  = @old_content.inline? ? @old_content.body : ''

    # file upload: list of supported formats
    upload_formats = (config['format']['image'].to_a + config['format']['other'].to_a).collect {|format|
      file_extension(format)
    }.uniq.join(', ')
    # file upload: maximal size of file
    upload_file_size = display_file_size(config['limit']['content'])


    tags = if @tag
      @tag
    elsif options.include?(:show_tags) && @member.allowed_to?('vote')
      tag_list
    end

    # more optional options
    lnames = language_names
    langs  = ([@request.language] + config['locale']['languages'].to_a).uniq.collect {|l|
            [l, lnames[l]] }

    msg_lang = @message.lang

    advanced_formats = ['text/plain', 'application/x-squish']
    formats = ([nil] + config['format']['inline'].to_a).collect {|format|
            if @request.advanced_ui? or not advanced_formats.include?(format)
              [format, site.plugins.find('content_inline', format).format_name]
            end
          }.compact
    old_format = @old_content.format

    disable_open = options.include?(:disable_open)
    msg_open = @message.open
    attach_parts = options.include?(:attach_parts)

    if lock_date = (@message.date.respond_to?(:to_time) and options.include?(:lock_date))
      date = @message.date.to_time.to_i
    end

    plugins = site.plugins.find_all('spam', :add_message_fields, :check_message_fields) do |plugin|
      plugin.add_message_fields(@request)
    end

    render_template('message_content_for_post.rhtml', binding)
  end

  def preview
    body = @message.content.body
    if body and body != limit_string(body, config['limit']['short'])
      cut_warning = '<p>'+sprintf(_('Warning: content is longer than %s characters. In some situations, it will be truncated.'), config['limit']['short'])+'</p>'
    end

    @title = _('Message Preview')
    @content_for_layout = render_template('message_preview.rhtml', binding)
  end

  def update_tag
    if @tag and @member.id
      @tag.related ||= @message.id
      @tag.vote(@member, 1)
      # (when publishing new message, tag rating is always '1')
    end
  end

  def update_html
    ([ @message ] + @message.parts).each do |message|
      Content.new(site, message).update_html(@request)
    end
  end

  # wrap save actions in a transaction, log moderatorial action if requested,
  # and ensure cache is flushed
  #
  def save(log_action = nil)
    @request.assert_action_confirmed
    db.transaction do
      log_moderation(log_action) if log_action
      yield
      @upload.status = 'confirmed' if @upload
      cache.flush
    end
  end
end
