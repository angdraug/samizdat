# Samizdat engine deployment functions
#
#   Copyright (c) 2002-2011  Dmitry Borodaenko <angdraug@debian.org>
#
#   This program is free software.
#   You can distribute/modify this program under the terms of
#   the GNU General Public License version 3 or later.
#
# vim: et sw=2 sts=2 ts=8 tw=0

require 'samizdat'
require 'syncache'
require 'graffiti'


# Shared in-process cache.
#
class CacheSingleton < SynCache::Cache
  include Singleton

  # size limit for in-process cache
  LOCAL_SIZE = 2000

  def initialize
    super(nil, LOCAL_SIZE)
  end
end


# load and operate mapping of server prefixes to Samizdat site names
#
class SamizdatSites
  include Singleton

  SITES_MAP = '/etc/samizdat/sites.yaml'

  # loads Samizdat sites mapping from /etc/samizdat/sites.yaml
  #
  def initialize
    File.readable?(SITES_MAP) or raise RuntimeError,
      "Can't read sites map from #{SITES_MAP}"

    @sites = {}
    sites_raw = load_yaml_file(SITES_MAP, true)
    sites_raw.each do |server_name, map|
      @sites[server_name] = sites_raw[server_name].keys.sort_by {|p|
        -p.size
      }.collect {|prefix|
        site_name = map[prefix]
        prefix = normalize_prefix(prefix)

        [ prefix,
          Regexp.new(/\A#{Regexp.escape(prefix)}(.*)\z/).freeze,
          site_name
        ]
      }
    end
  end

  # determine site, URI prefix, and route from CGI variables
  #
  # prefixes are sorted by descending length so that more specific prefixes are
  # tried before shorter ones
  #
  def find(host, request_uri)
    @sites[host] or raise RuntimeError,
      "Host '#{host}' is not configured in the sites map"

    request_route = request_uri.split('?', 2)[0]   # drop GET parameters

    @sites[host].each do |prefix, prefix_pattern, site_name|
      match = prefix_pattern.match(request_route)
      if match.kind_of? MatchData
        site = CacheSingleton.instance.fetch_or_add('site/' + site_name) do
          Site.new(site_name)
        end
        return site, prefix, match[1]
      end
    end

    # todo: fallback to `pwd`/config.yaml when lookup in global config fails
    raise SiteNotFoundError, request_route
  end

  # return list of all site names
  #
  def all
    sites = {}
    @sites.each {|server_name, map|
      map.each {|prefix, prefix_pattern, site| sites[site] = true }
    }
    sites.keys
  end

  private

  def normalize_prefix(prefix)
    if '/' == prefix
      prefix = ''
    elsif '/' == prefix[-1, 1]
      prefix.sub!(%r{/+\z}, '')
    end

    prefix
  end
end


# todo: document this class
# 
class ConfigHash < Hash

  # pre-load with supplied hash
  #
  def initialize(hash)
    super()
    self.deep_update!(hash)
  end

  # translate to option or ConfigHash of suboptions
  #
  def method_missing(name, *args)
    value = self[name.to_s]
    case value
    when nil then nil
    when Hash then ConfigHash.new(value)
    else value
    end
  end

  # traverse the tree of sub-hashes and only update modified values
  #
  def deep_update!(hash)
    hash.each do |key, value|
      if value.kind_of? Hash then
        case self[key]
        when ConfigHash then self[key].deep_update!(value)
        when Hash then self[key] = ConfigHash.new(self[key]).deep_update!(value)
        else self[key] = value   # scalar or nil is discarded in favor of hash
        end
      else
        self[key] = value
      end
    end
    self
  end
end


# Load, merge in, and cache site configuration from rdf.yaml, defaults.yaml,
# and <site>.yaml (in that order), cache a Whitewash object.
#
class SiteConfig

  # location of site-specific configs
  SITES_DIR = '/etc/samizdat/sites/'

  def initialize(site)
    @config = ConfigHash.new(DefaultRdfConfig.instance.config)
    @config.deep_update!(DefaultSiteConfig.instance.config)

    site_config =
      if site =~ %r{/.*/config\.yaml\z} and File.readable? site
        site   # config.yaml in current directory
      else
        File.join(SITES_DIR, site + '.yaml')
      end
    site_config = load_yaml_file(site_config, true)

    if site_config.has_key?('map')
      # override whole RDF config instead of merging it
      %w[ns map subproperties transitive_closure].each {|k| @config[k] = {} }
    end

    @config.deep_update!(site_config)
  end

  # Simpler delegation: no respond_to?() check, rely on target's
  # method_missing(), instead.
  #
  def method_missing(m, *args)
    @config.send(m, *args)
  end
end


# Wraps SynCache::Cache methods to prepend cache key with a site_name based
# prefix.
#
class SiteCache
  def initialize(cache, site_name)
    @cache = cache
    @site_name = site_name
  end

  def flush_base(base = '')
    Regexp.new('\A' + Regexp.escape(prefix) + base.to_s)
  end

  def flush(base = flush_base)
    @cache.flush(base)
  end

  def delete(key)
    @cache.delete(prefix + key)
  end

  def []=(key, value)
    @cache[prefix + key] = value
  end

  def [](key)
    @cache[prefix + key]
  end

  def fetch_or_add(key, &p)
    @cache.fetch_or_add(prefix + key, &p)
  end

  def prefix
    "samizdat/#{@site_name}/"
  end
end


class Site
  def initialize(name)
    @name = name
    @config = SiteConfig.new(@name)

    @local_cache = SiteCache.new(CacheSingleton.instance, @name)
    if @config.cache and @config.cache =~ /\Adruby:/
      @shared_cache = CacheSingleton.instance.fetch_or_add('drb/' + @config.cache) do
        SynCache::RemoteCache.new(@config.cache)
      end
      @cache = SiteCache.new(@shared_cache, @name)
    else
      @shared_cache = CacheSingleton.instance
      @cache = @local_cache
    end

    if @config.timezone
      begin
        require 'tzinfo'
        @timezone = TZInfo::Timezone.get(@config.timezone)
        @timezone = nil if @timezone == SystemTimezone.instance.timezone
      rescue LoadError
        # no timezone conversion if TZInfo is not available
      end
    end

    if @config.plugins
      @plugins = Plugins.new(self)   # circular reference
    end
  end

  attr_reader :name, :config, :cache, :local_cache, :shared_cache, :plugins, :timezone

  def whitewash
    # todo: allow sites to override the default Whitewash whitelist
    WhitewashSingleton.instance
  end

  # Check if all parameters necessary to send out emails are set.
  #
  def email_enabled?
    @config['email'] and @config['email']['address'] and @config['email']['sendmail']
  end

  # Directory for media uploads. Watch it: Samizdat will try to write there!
  #
  def content_dir
    if @content_dir.nil?
      @content_dir = @config['site']['content_dir']

      unless @content_dir.kind_of?(String) and
        File.directory?(@content_dir) and
        File.writable?(@content_dir)

        @content_dir = false 
      end
    end

    @content_dir
  end

  # Check if multimedia content upload is possible.
  #
  def upload_enabled?
    content_dir.kind_of?(String)
  end

  # Check if format is supported by the site, untaint it if it is.
  #
  def validate_format(format)
    @config['format'].values.flatten.include?(format) or raise UnknownFormatError,
      sprintf(_("Format '%s' is not supported"), Rack::Utils.escape_html(format))
    format.untaint
  end

  # database connection management
  #
  # permanently keeps DB connections in in-process cache
  #
  def db
    # todo: verify concurrency in db and storage
    # todo: check connection timeouts, auto-reconnect
    # optimize: generate connection pool
    local_cache.fetch_or_add('database') do
      config['db']['adapter'] or raise RuntimeError,
        'Invalid database connection configuration: adapter not defined'
      db = Sequel.connect(
        :adapter => config['db']['adapter'],
        :host => config['db']['host'],
        :database => config['db']['database'],
        :user => config['db']['user'],
        :password => config['db']['password'],
        :quote_identifiers => false
      )
      db.extension(:sequel_3_dataset_methods)
      db
    end
  end

  # rdf storage access shortcut
  #
  def rdf
    local_cache.fetch_or_add('rdf') do
      Graffiti::Store.new(db, config)
    end
  end
end


# Shortcuts for site configuration. Classes including this helper must have
# @site instance variable initialized.
#
module SiteHelper
  include Sequel::SQL::Constants

  attr_reader :site

  def config
    @site.config
  end

  def cache
    @site.cache
  end

  def local_cache
    @site.local_cache
  end

  def shared_cache
    @site.shared_cache
  end

  def db
    @site.db
  end

  def rdf
    @site.rdf
  end

  def limit_page
    config['limit']['page']
  end

  if RUBY_VERSION < '1.9'
    def limit_string_size(string)
      $KCODE = 'utf8'
      string.jsize
    end

    def limit_string_cut(string, limit)
      string.each_char[0, limit - 1].join
    end

    def ellipsis
      "\xe2\x80\xa6"
    end

  else
    def limit_string_size(string)
      string.size
    end

    def limit_string_cut(string, limit)
      string[0, limit - 1]
    end

    def ellipsis
      "\u2026"
    end
  end

  # return _string_ truncated to the _limit_, with ellipsis if necessary
  #
  def limit_string(string, limit=config['limit']['title'])
    return nil unless string.kind_of? String

    if limit_string_size(string) > limit
      limit_string_cut(string, limit).sub(
        # cut back to the last word boundary
        /\s+\S*?\z/, ''
      ) + ellipsis
    else
      string
    end
  end

  def file_extension(format)
    config['file_extension'][format] or format.sub(%r{\A.*/(x-)?}, '')
  end

  def format_type(format)
    if format.nil? or config['format']['inline'].include?(format)
      :inline
    elsif config['format']['image'].include?(format)
      :image
    else
      :other
    end
  end

  def try_config(path, fallback=nil)
    if path.kind_of? String
      path = path.split '/'
    elsif !path.kind_of? Array
      raise "Path is neither String nor Array"
    end

    cfg = config
    ret = begin
      path.each {|p| cfg = cfg[p] }
      cfg
    rescue
    end

    ret or fallback
  end
end
