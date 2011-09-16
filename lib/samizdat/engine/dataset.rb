# Samizdat DataSet class
#
#   Copyright (c) 2002-2009  Dmitry Borodaenko <angdraug@debian.org>
#
#   This program is free software.
#   You can distribute/modify this program under the terms of
#   the GNU General Public License version 3 or later.
#
# vim: et sw=2 sts=2 ts=8 tw=0

require 'samizdat'

class DataSet
  include SiteHelper

  def initialize(site, query, limit = nil)
    @site = site
    @query = query
    @limit = (limit or limit_page)
    @cache_key = generate_key(query)
  end

  attr_reader :limit

  def size
    @size ||= cache.fetch_or_add(@cache_key + 'size') do
      fetch_count(@query)
    end
  end

  alias :length :size

  def empty?
    0 == size
  end

  def [](offset)
    return [] if offset < 0 or empty? or (@limit.nil? and offset > 0) or @limit.to_i * offset > size

    cache.fetch_or_add(@cache_key + offset.to_s) do
      fetch(@query, @limit, @limit.to_i * offset)
    end
  end

  private

  def generate_key(seed)
    'dataset_' << digest(seed) << "/limit=#{@limit}/"
  end

  def fetch(query, limit = nil, offset = nil)
    raise RuntimeError, "Abstract method called"
  end

  def fetch_count(query)
    raise RuntimeError, "Abstract method called"
  end
end

class SqlDataSet < DataSet

  private

  def fetch(query, limit = nil, offset = nil)
    limit and query << " LIMIT #{limit}"
    offset and query << " OFFSET #{offset}"
    db.select_all(query)
  end

  def fetch_count(query)
    db.select_one(%{SELECT COUNT(*) FROM (#{query}) AS s})[0]
  end
end

class RdfDataSet < DataSet
  def initialize(site, query, limit = nil, params = {})
    super(site, query, limit)
    self.params = params
  end

  def params=(params)
    @params = params

    # reset cached state
    @cache_key = generate_key(@query + @params.to_s)
    @size = nil
  end

  private

  def fetch(query, limit = nil, offset = nil)
    rdf.select_all(query, limit, offset, @params)
  end

  def fetch_count(query)
    sql, *values = rdf.select(query, @params)
    db.select_one(%{SELECT COUNT(*) FROM (#{sql}) AS s}, *values)[0]
  end
end

class EmptyDataSet < DataSet
  def initialize(site)
    @limit = site.config['limit']['page']
    @size = 0
  end

  def [](offset)
    []
  end
end
