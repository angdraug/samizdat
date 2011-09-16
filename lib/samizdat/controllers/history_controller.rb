# Samizdat message history
#
#   Copyright (c) 2002-2009  Dmitry Borodaenko <angdraug@debian.org>
#
#   This program is free software.
#   You can distribute/modify this program under the terms of
#   the GNU General Public License version 3 or later.
#
# vim: et sw=2 sts=2 ts=8 tw=0

class HistoryController < Controller

  def index
    page = (@request['page'] or 1).to_i

    resource = Resource.new(@request, @id)

    @title = _(resource.type) + ' / ' + resource.title + ' / ' +
      _('History of Changes') + page_number(page)
    resource = nil

    # current version
    versions = (page > 1 ? [] : [ @id ])

    # previous versions
    dataset = RdfDataSet.new(site, %{
      SELECT ?version
      WHERE (dct::isVersionOf ?version #{@id})
            (dc::date ?version ?date)
      ORDER BY ?date DESC})
    dataset[page - 1].each {|version,| versions.push version }
    last, = dataset[page][0] if dataset.size > page * limit_page

    # table of changes
    compare = _('compare with previous version')
    0.upto(versions.size - 1) do |i|
      diff_link =
        if i < versions.size - 1
          %{<a href="diff?old=#{versions[i+1]}&amp;new=#{versions[i]}">#{compare}</a>}
        elsif last
          # offer diff for last on page if not last in history
          %{<a href="diff?old=#{last}&amp;new=#{versions[i]}">#{compare}</a>}
        end
      versions[i] = [ Resource.new(@request, versions[i]).list_item, diff_link ]
    end

    versions.unshift [_('Versions'), _('Changes')]

    @content_for_layout = box(@title, table(versions, nav(dataset)))
  end
end
