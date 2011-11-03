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

    tags = [[_('Tag'), _('Related Resources')]] +
      dataset[page - 1].collect {|tag, nrelated|
        subtags = rdf.select_all('
          SELECT ?subtag
          WHERE (s::subTagOf ?subtag :tag)
          ORDER BY ?subtag', limit_page, 0,
          { :tag => tag })

        subtags = subtags.collect! {|subtag,|
          resource_href(subtag, Resource.new(@request, subtag).title)
        }.join(', ')

        unless subtags.empty?
          subtags = _('subtags') + ': ' + subtags
        end

        if @request.moderate?
          subtags << ', ' unless subtags.empty?
          subtags << link("tags/#{tag}/add_subtag", _('add a sub-tag'))
        end

        unless subtags.empty?
          subtags = ' (' + subtags + ')'
        end

        [ resource_href(tag, Resource.new(@request, tag).title) + subtags,
          nrelated ]
      }

    @title = config['site']['name'] + ': ' +
      _('Top Tags') + page_number(page)
    @content_for_layout = box(@title,
      table(tags, nav(dataset)))
  end

  def add_subtag
    assert_moderate

    subtag, = @request.values_at %w[subtag]

    if @id and subtag
      subtag = (Model.validate_id(subtag) or
                raise ResourceNotFoundError, subtag)

      db.transaction do |db|
        log_moderation('subtag')
        rdf.assert('
          UPDATE ?sub_tag_of = :tag
          WHERE (s::subTagOf :subtag ?sub_tag_of)',
          {:tag => @id, :subtag => subtag})
      end
      cache.flush

      @request.redirect('tags')

    else
      @title = _('Add a sub-tag')
      @content_for_layout = box(@title,
        secure_form(nil,
          [:label, 'subtag', _('Enter Sub-Tag ID')],
            [:text, 'subtag'],
          [:submit, 'submit', _('Submit')])
      )
    end
  end
end
