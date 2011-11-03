# Samizdat tag handling
#
#   Copyright (c) 2002-2011  Dmitry Borodaenko <angdraug@debian.org>
#
#   This program is free software.
#   You can distribute/modify this program under the terms of
#   the GNU General Public License version 3 or later.
#
# vim: et sw=2 sts=2 ts=8 tw=0

require 'samizdat'

class Tag
  include SiteHelper

  # derive tag resource id from uriref when necessary; keep external uriref if
  # applies
  #
  # derive readable tag name from tag uriref
  #
  # if _related_ is a valid Resource id, #rating and #vote can be used
  #
  def initialize(site, id, related=nil)   # todo: unit-test this beast
    @site = site

    if Model.validate_id(id).nil?   # try uriref
      tag_ns = config['ns']['tag']
      if /\A(tag::|#{tag_ns})(.*)\z/ =~ id
        @name = $2
        @uriref = tag_ns + @name
      elsif id.kind_of?(String) and URI::URI_REF =~ id
        @name = @uriref = id
      end

      URI::URI_REF =~ @uriref or raise RuntimeError,
        "Invalid uriref '#{id}'"

      id = rdf.get_property(@uriref, 's::id')   # derive id from uriref
    end

    if id   # existing resource
      @id = id
    elsif @uriref.nil?   # not a virtual uriref resource
      raise ResourceNotFoundError, 'Tag ' + id.to_s
    end

    self.related = related

    @plugin = site.plugins.find('tag', self)
  end

  attr_reader :id, :uriref, :related

  def related=(related)
    @related = Model.validate_id(related)   # if nil, won't operate with rating
  end

  def to_s
    @id or @uriref
  end

  def name(request)
    @name ? _(@name) : Resource.new(request, @id).title
  end

  def display_vote_link?(member)
    @related and
      @plugin.allowed_to_vote?(member) and
      @plugin.applicable_to?(@related) and
      @plugin.visible?
  end

  # rating is an integer from -2 to 2
  #
  def Tag.validate_rating(rating)
    rating = rating.to_i if rating
    (rating and rating >= -2 and rating <= 2)? rating: nil
  end

  # render tag title
  #
  def Tag.tag_title(title)
    _(title) + ' (' + _('Tag') + ')'   # translate tag names
  end

  def Tag.related_dataset(site, id)
    RdfDataSet.new(site, %{
SELECT ?msg
WHERE (rdf::subject ?stmt ?msg)
      (rdf::predicate ?stmt dc::relation)
      (rdf::object ?stmt ?tag)
      (s::rating ?stmt ?rating FILTER ?rating > 0)
      (dc::date ?msg ?date)
      #{exclude_hidden('?msg')}
EXCEPT (dct::isPartOf ?msg ?parent)
OPTIONAL (dct::isPartOf ?tag ?supertag TRANSITIVE)
LITERAL ?tag = :id OR ?supertag = :id
ORDER BY ?date DESC}, site.config['limit']['page'], :id => id)
  end

  def Tag.tags_dataset(site)
    special_tags = Tag.find_special_tags(site)
    special_tags = special_tags.empty? ? '' :
      "AND id NOT IN (#{special_tags.join(', ')})"

    SqlDataSet.new(site, %{
      SELECT id, nrelated_with_subtags
      FROM Tag
      WHERE nrelated_with_subtags > 0
      #{special_tags}
      ORDER BY nrelated_with_subtags DESC},
      site.config['limit']['tags'])
  end

  def Tag.find_tags(site)
    list = Tag.tags_dataset(site)[0]

    if block_given?
      list.collect {|tag, usage| yield tag, usage }
    else
      list
    end
  end

  # list of all special tags ids
  #
  # if _include_virtual_ is +true+, virtual uriref tags (the ones that haven't
  # been assigned a resource id yet) will be included in the list
  #
  # watch for size of this list: it's used to generate IN() expressions
  #
  def Tag.find_special_tags(site, include_virtual = false)
    list = site.cache.fetch_or_add('special_tags') do
      site.plugins['tag'].collect {|plugin|
        plugin.find_all.transpose[0]
      }.flatten.uniq
    end

    include_virtual or list = list.select {|tag| Model.validate_id(tag) }

    if block_given?
      list.collect {|tag| yield tag }
    else
      list
    end
  end

  # read and cache rating from SamizdatRDF
  #
  def rating
    return nil unless @related
    if @rating.nil?
      @rating, = rdf.select_one %{
SELECT ?rating
WHERE (rdf::subject ?stmt #{@related})
      (rdf::predicate ?stmt dc::relation)
      (rdf::object ?stmt #{@id})
      (s::rating ?stmt ?rating)}

      @rating = @rating ? @rating.to_f : _('none')
    end
    @rating
  end

  # update rating in SamizdatRDF and in memory
  #
  def vote(member, value)
    return nil unless @related
    return nil unless value = Tag.validate_rating(value)
    raise UserError, _("You can't relate resource to itself") if @id == @related

    @plugin.pre_vote(member, @related)

    # always make sure @id and @uriref are SQL-safe
    rdf.assert( %{
UPDATE ?rating = :rating
WHERE (rdf::subject ?stmt :related)
      (rdf::predicate ?stmt dc::relation)
      (rdf::object ?stmt #{self.to_s})
      (s::voteProposition ?vote ?stmt)
      (s::voteMember ?vote :member)
      (s::voteRating ?vote ?rating)},
      { :rating => value, :related => @related, :member => member.id }
    )

    @rating = nil   # invalidate rating cache
    cache.flush
  end

  # order by rating, unrated after rated
  #
  def sort_index
    rating.kind_of?(Numeric) ? rating : -100
  end

  # print tag rating
  #
  def print_rating
    case rating
    when Numeric then "%4.2f" % rating
    when String then rating
    else rating.to_s
    end
  end

  def method_missing(method, *params)
    @plugin.send(method, *params)
  end
end
