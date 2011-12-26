# Samizdat resource list representation
#
#   Copyright (c) 2002-2011  Dmitry Borodaenko <angdraug@debian.org>
#
#   This program is free software.
#   You can distribute/modify this program under the terms of
#   the GNU General Public License version 3 or later.
#
# vim: et sw=2 sts=2 ts=8 tw=0

require 'samizdat'
require 'samizdat/helpers/application_helper'

# Render a list of resources from a given dataset.
#
# The list is opportunistically paginated using 'page' CGI parameter.
# The dataset must present resource id as :id column.
#
class ResourcesList
  include ApplicationHelper

  def initialize(request, dataset, style)
    self.request = request
    @dataset = dataset
    @dataset.key or raise RuntimeError,
      "Can't use a DataSet without a key in a resources list"
    @style = style
    @page = (@request['page'] or 1).to_i
    @data = dataset[@page - 1]
    @nav = nav(dataset)
  end

  attr_reader :dataset, :page

  def to_s
    self.respond_to?(@style) ? self.send(@style) : ''
  end

  def full
    @data.map {|r|
      Resource.new(@request, r[@dataset.key]).short
    }.join << %{<div class="foot">#{@nav}</div>}
  end

  alias :short :full

  def list_item
    items = @data.map {|r|
      Resource.new(@request, r[@dataset.key]).list_item
    }
    list(items, @nav)
  end
end

# Messages that are related to any tag (and are not comments or old versions),
# ordered chronologically by date of relation to a tag (so that when message is
# edited, it doesn't float up).
#
# In case of multiple related tags, the one related most recently is used.
#
class FeaturesList < ResourcesList
  def initialize(request, limit = nil)
    self.request = request
    limit ||= config.limit.features

    dataset = RdfDataSet.new(site,
%{SELECT ?msg
WHERE (rdf::predicate ?stmt dc::relation)
      (rdf::subject ?stmt ?msg)
      (rdf::object ?stmt ?tag)
      (dc::date ?stmt ?date)
      (s::rating ?stmt ?rating FILTER ?rating >= :threshold)
      #{exclude_hidden('?msg')}
EXCEPT (dct::isPartOf ?msg ?parent)
#{'OPTIONAL (dc::language ?msg ?original_lang)
         (s::isTranslationOf ?msg ?translation)
         (dc::language ?translation ?translation_lang)
LITERAL ?original_lang = :lang
     OR ?translation_lang = :lang' if request.monolanguage?}
GROUP BY ?msg
ORDER BY max(?date) DESC},
      :threshold => config['limit']['features_threshold'],
      :lang => request.language) {|ds|
      ds.limit = limit
      ds.key = :msg
    }

    super(request, dataset, :short)
    @nav = nav(dataset, :route => 'frontpage/features?')
  end
end

# Messages that are not comments, older versions or other kinds of parts,
# sorted chronologically.
#
class UpdatesList < ResourcesList
  def initialize(request)
    self.request = request

    dataset = RdfDataSet.new(site,
%{SELECT ?msg
WHERE (dc::date ?msg ?date)
      #{exclude_hidden('?msg')}
EXCEPT (dct::isPartOf ?msg ?parent)
#{'OPTIONAL (dc::language ?msg ?original_lang)
         (s::isTranslationOf ?msg ?translation)
         (dc::language ?translation ?translation_lang)
LITERAL ?original_lang = :lang
     OR ?translation_lang = :lang' if request.monolanguage?}
ORDER BY ?msg DESC},
      :lang => request.language) {|ds| ds.key = :msg }

    super(request, dataset, :list_item)
    @nav = nav(dataset, :route => 'frontpage/updates?')
  end
end
