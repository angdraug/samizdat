# Samizdat data model abstract class
#
#   Copyright (c) 2002-2009  Dmitry Borodaenko <angdraug@debian.org>
#
#   This program is free software.
#   You can distribute/modify this program under the terms of
#   the GNU General Public License version 3 or later.
#
# vim: et sw=2 sts=2 ts=8 tw=0

require 'samizdat'

class Model
  include SiteHelper

  # _id_ should be translatable to an Integer above zero
  #
  # returns nil if _id_ is invalid
  #
  def Model.validate_id(id)
    return nil unless id and id.to_i.to_s == id.to_s and id.to_i > 0
    id.to_i
  end

  def Model.cached(site, id)
    if id = Model.validate_id(id)
      site.cache.fetch_or_add("model/#{self}/#{id}") do
        self.new(site, id)
      end
    else
      self.new(site, nil)
    end
  end

  def initialize(site, id)
    @site = site
    @id = id if Model.validate_id(id)
    yield self if block_given?
  end
end
