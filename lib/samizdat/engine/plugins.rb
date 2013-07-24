# Samizdat plugin management
#
#   Copyright (c) 2002-2011  Dmitry Borodaenko <angdraug@debian.org>
#
#   This program is free software.
#   You can distribute/modify this program under the terms of
#   the GNU General Public License version 3 or later.
#
# vim: et sw=2 sts=2 ts=8 tw=0

require 'samizdat'

# plugin superclass
#
class Plugin
  include SiteHelper

  def initialize(site, options)
    @site = site
    @options = options
  end

  def api
    nil
  end

  def default?
    false
  end

  def match?(*params)
    false
  end

  # List of plugins this plugin depends on. Format:
  #
  #  [ [ api, requisite ], ... ]
  #
  def depends
    []
  end

  def self.register_as(type)
    PluginClasses.instance[type] = self
  end
end

# singleton Hash mapping plugin names to classes
#
class PluginClasses < Hash
  include Singleton
end

# plugins configuration for a Samizdat site
#
class Plugins
  def initialize(site)
    @plugins = {}
    @defaults = {}

    options = site.config.plugins['options']
    loaded = {}

    site.config.plugins.each do |api, plugins|
      next if 'options' == api
      @plugins[api] ||= []
      plugins.each {|name| load_plugin(site, api, name, options, loaded) }
    end
  end

  # list of non-default plugins for the _api_
  #
  def [](api)
    @plugins[api]
  end

  # default plugin for the _api_
  #
  def default(api)
    @defaults[api]
  end

  # find an _api_-compatible plugin for the _params_
  #
  def find(api, *params)
    plugin = nil

    @plugins[api] and @plugins[api].each do |p|
      if p.match?(*params)
        plugin = p
        break
      end
    end

    plugin or @defaults[api]
  end

  def find_all(api, *params)
    plugins = []

    @plugins[api].respond_to?(:each) and @plugins[api].each do |p|
      if p.match?(*params)
        plugins.push(p)
      end
    end

    plugins.push(@defaults[api]) if @defaults[api].kind_of?(Plugin)

    if block_given?
      plugins.collect {|p| yield p }
    else
      plugins
    end
  end

  private

  PLUGIN_NAME_PATTERN = Regexp.new(/\A[[:alnum:]_]+\z/).freeze

  # It is assumed that plugin initialization code will store a reference to its
  # class in the PluginClasses singleton hash.
  #
  def load_plugin(site, api, name, options, loaded)
    loaded[name] and return

    plugin_class = PluginClasses.instance[name]
    if plugin_class.nil?

      name =~ PLUGIN_NAME_PATTERN or raise RuntimeError,
        "Invalid plugin name '#{name}'"

      require %{samizdat/plugins/#{name}}
      plugin_class = PluginClasses.instance[name] or raise RuntimeError,
        "Plugin '#{name}' didn't register itself with PluginClasses"
    end

    plugin = plugin_class.new(
      site, (options[api] or {}).merge((options[name] or {})))

    loaded[name] = true

    plugin.depends.each do |requisite_api, requisite|
      load_plugin(site, requisite_api, requisite, options, loaded)
    end

    # register the plugin
    if plugin.default?
      @defaults[plugin.api] = plugin
    else
      @plugins[plugin.api] ||= []
      @plugins[plugin.api].push(plugin)
    end
  end
end
