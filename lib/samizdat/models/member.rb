# Samizdat member model
#
#   Copyright (c) 2002-2011  Dmitry Borodaenko <angdraug@debian.org>
#
#   This program is free software.
#   You can distribute/modify this program under the terms of
#   the GNU General Public License version 3 or later.
#
# vim: et sw=2 sts=2 ts=8 tw=0

require 'samizdat'

class Member < Model
  def initialize(site, id)
    super

    if @id
      @login = rdf.get_property(@id, 's::login')
      @full_name = rdf.get_property(@id, 's::fullName')
      @preferences = Preferences.new(site, @login)
      load_profile

    else
      @login = 'guest'
    end

    @full_name ||= @login

    @access = {}
    site.plugins['access'].each do |plugin|
      plugin.set_member_access(self)
    end
  end

  attr_reader :id, :login, :full_name, :preferences, :profile, :access

  def guest?
    @id.nil?
  end

  def location
    config['plugins']['route'].include?('blog') ? 'blog/' + @login : @id
  end

  def allowed_to?(action)
    allow = false
    site.plugins.find_all('access', self, action) do |plugin|
      if plugin.allow?
        allow = true
      else
        allow = false
        break
      end
    end

    allow
  end

  def assert_allowed_to(action)
    allowed_to?(action) or raise AuthError,
      sprintf(_('Your current access level (%s) does not allow to perform this action (%s)'),
        site.plugins['access'].collect {|plugin|
          plugin.display_member_access(self)
        }.join(', '), _(action))
  end

  def Member.find_who_can(site, action)
    query = site.plugins['access'].collect {|plugin|
      plugin.find_who_can(action)
    }.compact.join(' UNION ')

    if query.empty?
      EmptyDataSet.new(site)
    else
      SqlDataSet.new(site, query + %q{ ORDER BY member})
    end
  end

  def messages_dataset
    RdfDataSet.new(site, %{
SELECT ?msg
WHERE (dc::date ?msg ?date)
      (dc::creator ?msg :id)
EXCEPT (dct::isPartOf ?msg ?parent)
ORDER BY ?msg DESC}, limit_page, :id => @id)
  end

  private

  def load_profile
    @profile = {}
    site.plugins['profile'].each do |plugin|
      plugin.load_fields(self)
    end
  end
end


# miscellaneous member preferences
#
# stored in a text field as a YAML hash
#
class Preferences < DelegateClass(Hash)
  include SiteHelper

  # load member preferences by login
  #
  def initialize(site, login)
    @site = site
    @login = login

    if 'guest' == @login
      @prefs = {}
    else
      # todo: do we need to cache this?
      prefs, = db.select_one 'SELECT prefs FROM Member WHERE login = ?', @login
      @prefs = yaml_hash(prefs)
    end

    super @prefs
  end

  # save updated member preferences to database
  #
  # _confirm_ is an optional confirmation hash
  #
  def save(confirm=nil)
    return if 'guest' == @login
    @prefs or raise RuntimeError, 'No preferences to save'
    db.do 'UPDATE Member SET prefs = ?, confirm = ? WHERE login = ?',
      @prefs.to_yaml, confirm, @login
  end
end
