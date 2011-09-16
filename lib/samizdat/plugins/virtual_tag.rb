# Samizdat virtual tag plugins superclass
#
#   Copyright (c) 2002-2009  Dmitry Borodaenko <angdraug@debian.org>
#
#   This program is free software.
#   You can distribute/modify this program under the terms of
#   the GNU General Public License version 3 or later.
#
# vim: et sw=2 sts=2 ts=8 tw=0

require 'samizdat'
require 'samizdat/plugins/tag'

# virtual tag is a tag that is identified by a uriref under Samidat 'tag::'
# namespace, and potentially may have no Resource id assigned yet
#
class VirtualTagPlugin < TagPlugin
  def match?(tag)
    (
      tag.uriref and
      tag_names.include?(rdf.ns_shrink(tag.uriref))
    ) or tag_ids.include?(tag.id)
  end

  def find_all
    tag_ids.collect {|id| [ id, 0 ] }
  end

  private

  # list of virtual tag names in tag:: namespace (with "tag::" prefix included)
  #
  def tag_names
    []
  end

  def tag_ids
    cache.fetch_or_add('tag_ids/' + self.class.to_s) do
      tag_names.collect do |name|
        id, = rdf.select_one("SELECT ?id WHERE (s::id #{name} ?id)")
        id or name
      end
    end
  end
end
