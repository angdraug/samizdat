# Samizdat mock classes
#
#   Copyright (c) 2002-2009  Dmitry Borodaenko <angdraug@debian.org>
#
#   This program is free software.
#   You can distribute/modify this program under the terms of
#   the GNU General Public License version 3 or later.
#
# vim: et sw=2 sts=2 ts=8 tw=0

require 'samizdat'
require 'tzinfo'

class MockConfig < SiteConfig
  RDF = 'data/samizdat/rdf.yaml'
  DEFAULTS = 'data/samizdat/defaults.yaml'
  CONFIG = 'data/samizdat/config.yaml'

  def initialize
    @config = ConfigHash.new(load_yaml_file(RDF))
    @config.deep_update!(load_yaml_file(DEFAULTS))
    @config.deep_update!(load_yaml_file(CONFIG))
  end
end

class MockDb
  include Singleton

  def select_one(query, params={})
    nil
  end
end

class MockSite < Site
  include Singleton

  def initialize
    @name = 'samizdat'
    @config = MockConfig.new
    @cache = @local_cache = SiteCache.new(CacheSingleton.instance, @name)
    @shared_cache = CacheSingleton.instance
    @timezone = TZInfo::Timezone.get('Europe/London')
    @plugins = Plugins.new(self)
  end

  def content_dir
    ''
  end

  def upload_enabled?
    true
  end

  def db
    MockDb.instance
  end

  def rdf
    nil
  end
end

class MockSession
  def initialize
    @login = 'guest'
    @full_name = _(@login)
  end

  attr_accessor :member, :login, :full_name, :moderator

  def moderator?
    @moderator
  end
end

class MockRequest
  def initialize
    samizdat_bindtextdomain('C')
    @site = MockSite.instance
    @session = MockSession.new
    @moderate = false
    @options = {}
    @uri_prefix = ''
    @base = 'http://localhost/'
    @route = '/'
  end

  attr_accessor :site, :session, :moderate, :options, :uri_prefix, :base, :route

  def cookie(name)
    nil
  end

  def moderate?
    @moderate
  end
end

class MockMember
  def initialize(permissions = {})
    @id = 1
    @login = 'test'
    @full_name = 'Test'
    @permissions = permissions
  end

  attr_accessor :id, :login, :full_name

  def guest?
    'guest' == @login
  end

  def allowed_to?(action)
    @permissions[action]
  end

  def location
    @id.to_s
  end
end

class MockGuestMember < MockMember
  def initialize
    @id = nil
    @login = 'guest'
    @full_name = _(@login)
  end
end

class MockFromHash
  def initialize(params = {})
    @params = params
    @id = @params[:id]
  end

  attr_reader :id

  def method_missing(name, value = nil)
    if /=$/ =~ name.to_s
      @params[ name.to_s.sub(/=$/, '').to_sym ] = value
    else
      @params[name]
    end
  end
end

class MockMessage < MockFromHash
  def initialize(params = {})
    super
    @params = {
      :content => nil,
      :date => Time.now,
      :lang => nil,
      :creator => MockMember.new,
      :desc => nil,
      :parent => nil,
      :part_of_property => 'dct::isPartOf',
      :current => nil,
      :open => false,
      :nversions => 0,
      :translations => [],
      :nreplies => 0,
      :tags => [],
      :nrelated => 0,
      :moderation_log => []
    }.merge!(@params)

    @params[:content] ||= Content.new(MockSite.instance, @params[:id], @params[:creator].login)
  end

  def may_reply?
    true
  end
end

class MockUpload
  def path
    'mock_upload'
  end
end
