# Samizdat top tags list
#
#   Copyright (c) 2002-2011  Dmitry Borodaenko <angdraug@debian.org>
#
#   This program is free software.
#   You can distribute/modify this program under the terms of
#   the GNU General Public License version 3 or later.
#
# vim: et sw=2 sts=2 ts=8 tw=0

class TagsController < Controller

  def index
    dataset = Tag.tags_dataset(site)
    page = (@request['page'] or 1).to_i

    tags = 
      dataset[page - 1].collect {|tag, nrelated|
        subtags = rdf.fetch(%q{
          SELECT ?subtag
          WHERE (s::subTagOf ?subtag :tag)
          ORDER BY ?subtag}, :tag => tag[:id]
        ).limit(limit_page)

        [ tag, nrelated, subtags ]
      }

    @title = config['site']['name'] + _(': ') +
      _('Top Tags') + page_number(page)
    foot = nav(dataset)
    @content_for_layout = render_template('tags_index.rhtml', binding)
  end

  def add_subtag
    assert_moderate

    subtag, = @request.values_at %w[subtag]

    if @id and subtag
      subtag = (Model.validate_id(subtag) or
                raise ResourceNotFoundError, subtag)

      db.transaction do
        log_moderation('subtag')
        rdf.assert(%q{
          UPDATE ?sub_tag_of = :tag
          WHERE (s::subTagOf :subtag ?sub_tag_of)},
          :tag => @id, :subtag => subtag)
      end
      cache.flush

      @request.redirect('tags')

    else
      @title = _('Add a sub-tag')
      @content_for_layout = render_template('tags_add_subtag.rhtml', binding)
    end
  end
end
