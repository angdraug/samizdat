# Samizdat message model
#
#   Copyright (c) 2002-2009  Dmitry Borodaenko <angdraug@debian.org>
#
#   This program is free software.
#   You can distribute/modify this program under the terms of
#   the GNU General Public License version 3 or later.
#
# vim: et sw=2 sts=2 ts=8 tw=0

require 'samizdat'

class Message < Model
  def initialize(site, id)
    super

    @date = Time.now
    @version_of = nil
    @nversions = 0
    @nreplies = 0
    @nreplies_all = 0
    @translations = []
    @tags = []
    @nrelated = 0
    @parts = []

    if @id
      load_from_rdf

      @creator = Member.cached(site, @creator)

      @parts = parts_dataset[0].collect {|part,| Message.cached(site, part) }
      @content = Content.new(site, self)

      find_next_and_previous_parts

      unless @version_of
        @nversions, = rdf.select_one %{
SELECT count(?version)
WHERE (dct::isVersionOf ?version :id)}, :id => @id

        @nreplies, = rdf.select_one %{
SELECT count(?msg)
WHERE (s::inReplyTo ?msg :id)
      #{exclude_hidden('?msg')}}, :id => @id

        @nreplies_all, = rdf.select_one %{
SELECT count(?msg)
WHERE (s::inReplyTo ?msg :id TRANSITIVE)
      #{exclude_hidden('?msg')}}, :id => @id
      end

      unless @translation_of
        @translations = rdf.select_all(
%{SELECT ?lang, ?msg
WHERE (s::isTranslationOf ?msg :id)
      (dc::language ?msg ?lang)
      #{exclude_hidden('?msg')}
ORDER BY ?lang ASC}, limit_page, nil, :id => @id
      ).collect {|l, m| [l, m] }   # DBI::Row to Array
      end

      unless @part_of
        @tags = rdf.select_all(
%{SELECT ?tag
WHERE (rdf::subject ?stmt :id)
      (rdf::predicate ?stmt dc::relation)
      (rdf::object ?stmt ?tag)
      (s::rating ?stmt ?rating)
LITERAL ?rating > 0
ORDER BY ?rating DESC}, limit_page, nil, :id => @id
      ).collect {|t,| Tag.new(site, t, @id) }
        @nrelated, = db.select_one(%q{
          SELECT nrelated_with_subtags FROM Tag WHERE id = ?}, @id)
        @nrelated ||= 0
      end
    end
  end

  attr_accessor :id, :date, :creator, :content, :part_of, :part_sequence_number,
    :open, :tags, :parts, :next_part, :previous_part

  attr_reader :lang, :parent, :translation_of, :version_of, :sub_tag_of,
    :nversions, :translations, :nreplies, :nreplies_all, :nrelated

  def parent=(parent)
    @part_of = @parent = parent
  end

  def translation_of=(translation_of)
    @part_of = @translation_of = translation_of
  end

  def lang=(lang)
    if lang and not (
      config['locale']['languages'].include?(lang) or 'und' == lang)

      raise UserError, _('Specified language is not supported on this site')
    end

    @lang = lang
  end

  def to_i
    @id.to_i
  end

  def assert_current_version
    if @version_of
      raise UserError, sprintf(
        _('Only <a href="%s">current version</a> may be used for this action'),
        @version_of)
    end
  end

  # expects valid reference to a current version of a message that is different
  # from this message
  #
  def validate_reference(ref)
    begin
      ref = Model.validate_id(ref)
      ref or raise ResourceNotFoundError

      message = Message.cached(site, ref)
      if message.id == @id
        raise UserError, _('Recursive message reference not allowed')
      end
      message.assert_current_version

    rescue ResourceNotFoundError
      raise UserError, _('Invalid message reference')
    end

    ref
  end

  def validate_open(open)
    case open
    when 'true', true
      true
    when 'false', false, nil
      false
    else
      raise UserError, _('Invalid openForAll value')
    end
  end

  def hidden?
    if @version_of
      # inherit hidden status from current version
      Message.cached(site, @version_of).hidden?
    else
      @hidden
    end
  end

  def locked?
    if @locked.nil? and @parent
      # a reply inherits a locked status from parent unless explicitly
      # (un)locked
      Message.cached(site, @parent).locked?
    else
      @locked
    end
  end

  def may_reply?
    # can't reply to tags, parts, translations, or old versions
    (@part_of.nil? or @parent) and 0 == @nrelated and not locked?
  end

  # find available translation to the most preferred language
  #
  # returns Message object or self, when no translation is suitable
  #
  def select_translation(accept_language)
    return self unless @lang   # don't translate messages with no language

    t_row = nil
    accept_language.each do |l|
      break if l == @lang   # message already in preferred language
      t_row = @translations.assoc(l)   # [l, m]
      break unless t_row.nil?
    end
    t_row ? Message.cached(site, t_row[1]) : self
  end

  def part_of_property
    if @parent
      's::inReplyTo'
    elsif @translation_of
      's::isTranslationOf'
    elsif @sub_tag_of
      's::subTagOf'
    elsif @version_of
      'dct::isVersionOf'
    elsif @part_of
      'dct::isPartOf'
    end
  end

  def hide!(hide)
    db.do 'UPDATE Message SET hidden = ? WHERE id = ?', hide, @id
  end

  def lock!(lock)
    db.do 'UPDATE Message SET locked = ? WHERE id = ?', lock, @id
  end

  def reparent!(new_parent, property, part_sequence_number = nil)
    new_parent &&= validate_reference(new_parent)

    unless 'dct::isPartOf' == property or (
      map = rdf.config.map[rdf.config.ns_expand(property)] and 
      'dct::isPartOf' == rdf.ns_shrink(map.subproperty_of) and
      property != 'dct::isVersionOf'
    )

      raise RuntimeError,
        "Invalid property #{CGI.escapeHTML(property)} passed to reparent!"
    end

    if new_parent.nil? and @content.title.nil?
      raise UserError, _("Set message title before reparenting")
    end

    rdf.select_all(
      %q{SELECT 0 WHERE (dct::isPartOf :new_parent :id TRANSITIVE)},
      nil, nil, :id => @id, :new_parent => new_parent
    ).empty? or raise UserError,
      _('Invalid new parent: message cannot be a part of its own part')

    part_sequence_number &&= part_sequence_number.to_i

    query =
      if 'dct::isPartOf' == property
        %{UPDATE ?parent = :new_parent, ?subproperty = NULL, ?seq = :seq
           WHERE (dct::isPartOf :id ?parent)
                 (s::isPartOfSubProperty :id ?subproperty)
                 (s::partSequenceNumber :id ?seq)}
      else
        %{UPDATE ?parent = :new_parent
           WHERE (#{property} :id ?parent)}
      end

    rdf.assert(query, {
      :id => @id,
      :new_parent => new_parent,
      :seq => part_sequence_number
    })

    @part_of = new_parent   # fixme: update other attributes
  end

  def insert!
    @id, = rdf.assert( %{
INSERT ?msg
WHERE (dc::creator ?msg :creator)
      (dc::title ?msg :title)
      (dc::language ?msg :language)
      (dc::format ?msg :format)
      (dc::date ?msg :date)
      (s::content ?msg :content)
      (s::openForAll ?msg :open)
      (#{part_of_property or 'dct::isPartOf'} ?msg :part_of)},
      { :date => @date.httpdate, :creator => @creator.id, :title => @content.title,
        :language => @lang, :format => @content.format, :content => @content.body,
        :open => (@open or false),
        :part_of => (@parent or @translation_of or @part_of) } )

    if @parts and not @parts.empty?
      @parts.collect! do |part|
        part.part_of = @id
        part.insert!
        Message.new(site, part.id)
      end
    end

    update_content
  end

  def edit!(old_content)
    @id or raise UserError, _('Reference to previous version lost')

    # save old version at new id
    db.do('
      INSERT INTO Message (
        creator, title, language, format, content, open,
        html_full, html_short)
      SELECT
        creator, title, language, format, content, open,
        html_full, html_short
      FROM Message
      WHERE id = ?', @id)
    version, = db.select_one 'SELECT MAX(id) FROM Resource'
    db.do(%q{
      UPDATE Resource
      SET published_date = (
            SELECT published_date FROM Resource WHERE id = ?),
          part_of = ?,
          part_of_subproperty = ?
      WHERE id = ?},
      @id, @id, version_of_resource_id, version)
    old_content.id = version

    # write new version at old id
    db.do '
      UPDATE Message
      SET creator = ?, title = ?, format = ?, content = ?, language = ?
      WHERE id = ?',
      @creator.id, @content.title, @content.format, @content.body, @lang, @id
    db.do '
      UPDATE Resource
      SET published_date = CURRENT_TIMESTAMP
      WHERE id = ?', @id

    unless @open.nil?   # change s:openForAll
      db.do 'UPDATE Message SET open = ? WHERE id = ?',
        (@open or false), @id
    end

    update_content
  end

  # replace content without saving previous version
  #
  def replace!(old_content)
    db.do "UPDATE Message SET creator = ?, title = ?, language = ?, format = ?,
      content = ?, open = ? WHERE id = ?",
      @creator.id, @content.title, @lang, @content.format,
      @content.body, false, @id

# todo: make Graffiti::SquishAssert grok this 
#
#        rdf.assert( %{
#ASSERT (dc::creator ?msg :creator)
#       (dc::title ?msg :title)
#       (dc::language ?msg :lang)
#       (dc::format ?msg :format)
#       (s::content ?msg :content)
#       (s::openForAll ?msg ?open)
#WHERE (s::id ?msg #{@id})},
#          { :creator => @creator.id, :title => @content.title, :lang => @lang,
#            :format => @content.format, :content => @content.body,
#            :open => false } )

    if (file = old_content.file).respond_to? :delete
      file.delete
    end
    update_content
  end

  def parts_dataset(id = @id)
    RdfDataSet.new(site, %{
SELECT ?part
WHERE (dct::isPartOf ?part :id)
      #{exclude_hidden('?part')}
EXCEPT (s::isPartOfSubProperty ?part ?subproperty)
OPTIONAL (s::partSequenceNumber ?part ?seq)
ORDER BY ?seq, ?part}, limit_page, :id => id)
  end

  private

  def load_from_rdf
    @date, @creator, @lang, @part_of, @parent, @version_of, @translation_of, @sub_tag_of, @part_sequence_number, @hidden, @locked, @open =
      rdf.select_one(%{
SELECT ?date, ?creator, ?lang, ?part_of, ?parent, ?version_of, ?translation_of, ?sub_tag_of, ?part_sequence_number, ?hidden, ?locked, ?open
WHERE (dc::date :id ?date)
OPTIONAL (dc::creator :id ?creator)
         (dc::language :id ?lang)
         (dct::isPartOf :id ?part_of)
         (s::inReplyTo :id ?parent)
         (dct::isVersionOf :id ?version_of)
         (s::isTranslationOf :id ?translation_of)
         (s::subTagOf :id ?sub_tag_of)
         (s::partSequenceNumber :id ?part_sequence_number)
         (s::hidden :id ?hidden)
         (s::locked :id ?locked)
         (s::openForAll :id ?open)}, :id => @id)

    raise ResourceNotFoundError, 'Message ' + @id.to_s if @date.nil?
  end

  def find_next_and_previous_parts
    return unless @part_of and 'dct::isPartOf' == part_of_property

    dataset = parts_dataset(@part_of)
    index = nil   # scope fix

    0.upto((dataset.size - 1) / dataset.limit) do |page|
      if index = dataset[page].find_index {|part,| part == @id }
        index += page * dataset.limit
        break
      end
    end

    return unless index

    if index > 0
      @previous_part, = dataset[(index - 1) / dataset.limit][(index - 1) % dataset.limit]
    end

    if index < dataset.size - 1
      @next_part, = dataset[(index + 1) / dataset.limit][(index + 1) % dataset.limit]
    end
  end

  def update_content
    @content.id = @id
  end

  def version_of_resource_id
    label = rdf.config.ns_expand('dct::isVersionOf')
    id, = db.select_one(
      %q{SELECT id FROM Resource WHERE uriref = 'true' AND label = ?}, label)

    return id if id

    db.do(
      %q{INSERT INTO Resource (uriref, label) VALUES ('true', ?)}, label)
    id, = db.select_one 'SELECT MAX(id) FROM Resource'
    return id
  end
end
