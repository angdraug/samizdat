# Samizdat search query construction
#
#   Copyright (c) 2002-2011  Dmitry Borodaenko <angdraug@debian.org>
#
#   This program is free software.
#   You can distribute/modify this program under the terms of
#   the GNU General Public License version 3 or later.
#
# vim: et sw=2 sts=2 ts=8 tw=0

require 'graffiti'

class QueryController < Controller

  def index
    query = (@request['q'] or DEFAULT_QUERY)
    q = validate_query(query)

    @title = _('Edit Query')
    @content_for_layout = box(@title, edit_box(q))
  end

  def run(query = @request['q'])
    @request.redirect('query') if query.nil?
    q = validate_query(query)

    page = (@request['page'] or 1).to_i

    @title = _('Search Result') + page_number(page)

    dataset = query_dataset(q)
    results = dataset[page - 1].map {|r| Resource.new(@request, r[dataset.key]).list_item }

    if results.size > 0
      feed = rss_link(query)
      @feeds[@title] = feed
    end

   @content_for_layout = render_template('query_result.rhtml', binding)
  end

  # search messages by a substring
  #
  def search
    substring = @request['substring']

    @request.redirect('query') if substring.nil?

    query = %{SELECT ?msg
WHERE (dc::date ?msg ?date)
      (dc::title ?msg ?title)
EXCEPT (dct::isVersionOf ?msg ?current)
LITERAL ?title ILIKE '%#{substring.gsub(/%/, '\\\\\\%')}%'
ORDER BY ?date DESC}

    run(query)
  end

  # regenerate query from form data
  #
  def update
    nodes, literal, order, order_dir, using =
      @request.values_at %w[nodes literal order order_dir using]

    # generate namespaces
    namespaces = config['ns']   # standard namespaces
    namespaces.update(Hash[*using.split]) if using

    using = {}

    # generate query pattern
    pattern = []
    @request.keys.grep(/\A(predicate|subject|object)_(\d{1,2})\z/) do |key|
      value = @request[key]
      next unless value
      i = $2.to_i - 1
      pattern[i] = [] unless pattern[i].kind_of?(Array)
      pattern[i][ %w[predicate subject object].index($1) ] = value
      namespaces.each do |p, uri|
        if /\A#{p}::/ =~ value
          using[p] = uri   # only leave used namespace prefixes
          break
        end
      end
    end
    @request.redirect('query') if pattern.empty?

    query = "SELECT #{nodes}\nWHERE " <<
      pattern.collect {|predicate, subject, object|
        "(#{predicate} #{subject} #{object})" if
          predicate and subject and object and predicate !~ /\s/
          # whitespace is only present in 'BLANK CLAUSE'
        }.compact.join("\n      ")
    query << "\nLITERAL #{literal}" if literal
    query << "\nORDER BY #{order} #{order_dir}" if order
    query << "\nUSING " + using.to_a.collect {|n|
      n.join(' FOR ')
    }.join("\n      ")

    run(query)
  end

  # RSS feed of a query run
  #
  def rss
    query = @request['q']
    q = validate_query(query)

    feed_page('query/' + digest(query)) do |maker|
      maker.channel.title = config['site']['name'] + ' / ' + _('Search Result')
      maker.channel.description = Rack::Utils.escape_html(query)
      maker.channel.link = @request.base + rss_link(query)
      query_dataset(q)
    end
  end

  private

  DEFAULT_QUERY = %{SELECT ?resource\nWHERE (dc::date ?resource ?date)\nORDER BY ?date DESC}

  # validate query (syntax, must-bind list size, number of clauses)
  #
  def validate_query(query)
    begin
      q = Graffiti::SquishSelect.new(rdf.config, query)
      sql = rdf.select(q)
    rescue Graffiti::ProgrammingError
      raise UserError, _('Error in your query: ') + Rack::Utils.escape_html($!.message)
    end

    (q.nodes.size != 1 or not Graffiti::SquishSelect::BN === q.nodes.first) and raise UserError,
      _('Must-bind list should contain only one blank node, filters based on queries with a complex answer pattern are not implemented')

    (q.pattern.size > config['limit']['pattern']) and raise UserError,
      sprintf(_('User-defined query pattern should not be longer than %s clauses'), config['limit']['pattern'])

    q
  end

  def query_dataset(query)
    SqlDataSet.new(site, query.to_sql) do |ds|
      ds.key = query.nodes.first.sub(Graffiti::SquishQuery::BN, '\1').to_sym
    end
  end

  def edit_box(q)
    clauses = ((q.pattern.size >= config['limit']['pattern'])?
          q.pattern :
          q.pattern + [['']]
        ).collect {|clause|
          predicate, subject, object = clause.first(3).collect {|uri| q.ns_shrink(uri) }
        }

    if @request.advanced_ui?
      properties = config['map'].keys
      if config['subproperties']
        properties += config['subproperties'].values.flatten
      end
      properties.sort!
    end

    render_template('query_edit_box.rhtml', binding)
  end

  def rss_link(query)
    %{query/rss?q=#{Rack::Utils.escape(query)}}
  end
end
