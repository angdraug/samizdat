# Samizdat message history
#
#   Copyright (c) 2002-2011  Dmitry Borodaenko <angdraug@debian.org>
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
    dataset[page - 1].each {|r| versions.push r[:version] }
    last = dataset[page].first[:version] if dataset.size > page * limit_page

    foot = nav(dataset)

    @content_for_layout = render_template('history_index.rhtml', binding)
  end
end
