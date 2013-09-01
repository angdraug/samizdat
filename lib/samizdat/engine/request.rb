# Samizdat request handling
#
#   Copyright (c) 2002-2011  Dmitry Borodaenko <angdraug@debian.org>
#
#   This program is free software.
#   You can distribute/modify this program under the terms of
#   the GNU General Public License version 3 or later.
#
# vim: et sw=2 sts=2 ts=8 tw=0

require 'samizdat'
require 'zlib'

class LocalDRbSingleton
  include Singleton

  def initialize
    @started = {}
  end

  if RUBY_VERSION < '1.9'
    def start(uri)
      Thread.critical = true
      unless @started[uri]
        @started[uri] = true
        Thread.critical = false
        DRb.start_service(uri)
      end
      Thread.critical = false
    end

  else
    def start(uri)
      mutex = Mutex.new
      mutex.lock
      if @started[uri]
        mutex.unlock
      else
        @started[uri] = true
        mutex.unlock
        DRb.start_service(uri)
      end
    end
  end
end

class UploadTempfile
  def initialize(tempfile, original_filename)
    @tempfile = tempfile
    @original_filename = original_filename
  end

  attr_reader :original_filename

  def path
    @tempfile.path
  end

  def method_missing(method, *args)
    @tempfile.send(method, *args)
  end
end

# CGI request and response handler
#
class Request
  # wrapper for Rack::Request#cookies (adds cookie name prefix)
  #
  def cookie(name)
    @rack.cookies[@cookie_prefix + name]
  end

  # create cookie and add it to the HTTP response
  #
  # cookie name prefix is configured via config.yaml; set expires to non-nil
  # value to create persistent cookie, use #forever as defined in
  # engine/helpers.rb to set a long-term cookie
  #
  def set_cookie(name, value = nil, expires = nil)
    Rack::Utils.set_cookie_header!(
      @headers,
      @cookie_prefix + name,
      {
        :value => value,
        :path => File.join(@uri_prefix, ''),
        :expires => expires.kind_of?(Numeric) ? Time.now + expires : nil,
        :secure => (ssl? and 'session' == name)
      }
    )
  end

  # set cookie to expire now
  #
  def unset_cookie(name)
    set_cookie(name, '', 0)
  end

  # get cached session, refresh or clear it
  #
  # don't cache guest and stale sessions
  #
  def cached_session
    c = cookie('session')

    if c and c =~ Session::COOKIE_PATTERN
      key = Session.cache_key(c)

      session = @site.cache.fetch_or_add(key) do
        s = Session.new(@site, c)
        s.member ? s : nil
      end

      if session and session.member and session.fresh!
        set_cookie('session', c, @site.config['timeout']['last'])
      else
        @site.cache.delete(key)
        unset_cookie('session')
      end
    end

    session or Session.new(@site, nil)
  end

  # set language of user interface
  #
  def language=(lang)
    lang = @site.config['locale']['languages'].first if
      lang.nil? or not @site.config['locale']['languages'].include?(lang)

    if @language and @accept_language.first == @language
      @accept_language.shift
    end
    @accept_language.unshift(lang)
    @accept_language.uniq!

    lang.untaint
    samizdat_bindtextdomain(lang, @site.config['locale']['path'])
    @language = lang
  end

  # current language
  attr_reader :language

  # Execute the supplied block under a different language.
  #
  def temporary_language(lang)
    if lang == @language
      yield
    else
      saved_language = @language
      self.language = lang
      result = yield
      self.language = saved_language
      result
    end
  end

  # set default CGI headers (set charset to UTF-8)
  #
  # set id and refresh session if there's a valid session cookie,
  # set credentials to guest otherwise
  #
  def initialize(env)
    @env = env
    @rack = Rack::Request.new(@env)
    @params = @rack.params

    @host = (
      @env['HTTP_X_FORWARDED_HOST'] or
      @env['HTTP_X_HOST'] or
      @env['SERVER_NAME'] or
      @env['HTTP_HOST']
    )

    @site, @uri_prefix, @route =
      SamizdatSites.instance.find(@host, @env['PATH_INFO'])

    LocalDRbSingleton.instance.start((@site.config.cache_callback or 'druby://localhost:0'))

    @headers = {}
    @status = 200

    @cookie_prefix = @site.config['site']['cookie_prefix'] + '_'

    set_language(@site.config['locale']['languages'], @env['HTTP_ACCEPT_LANGUAGE'])

    # construct @base
    scheme = @rack.scheme
    port = @rack.port
    port = (port == {'http' => 80, 'https' => 443}[scheme]) ? '': ':' + port.to_s
    @base = scheme + '://' + @host + port + File.join(@uri_prefix, '')

    # select CSS style
    @style = cookie('style')
    @style = @site.config['style'][0] unless @site.config['style'].include?(style)

    @session = cached_session
  end

  # raw CGI environment variables
  attr_reader :env

  # server name
  attr_reader :host

  # Site object representing specific Samizdat site accessed by this request
  attr_reader :site

  # URI prefix
  attr_reader :uri_prefix

  # route to controller action
  attr_accessor :route

  # base URI of the site, used to compose absolute links
  attr_reader :base

  # Session object
  attr_reader :session

  # list of languages in user's order of preference
  attr_reader :accept_language

  # preferred stylesheet
  attr_reader :style

  # HTTP response headers
  attr_reader :headers

  # HTTP response status
  attr_accessor :status

  def ssl?
    @rack.ssl?
  end

  def referer
    @rack.referer
  end

  # web server document root (untainted as it's assumed to be safe)
  #
  def document_root
    @document_root ||= @env['DOCUMENT_ROOT'].dup.untaint
  end

  def advanced_ui?
    'advanced' == cookie('ui')
  end

  def monolanguage?
    @site.config['locale']['allow_monolanguage'] and 'yes' == cookie('monolanguage')
  end

  # true if the user has and is wielding their moderator priviledges
  #
  def moderate?
    @session.moderator? and ('yes' == cookie('moderate'))
  end

  # return role name for the current user
  # ('moderator', 'member', or 'guest')
  #
  def role
    if moderate? then 'moderator'
    elsif @session.member then 'member'
    else 'guest'
    end
  end

  def _rgettext_hack   # :nodoc:
    [ _('moderator'), _('member'), _('guest') ]
  end
  private :_rgettext_hack

  def alt_styles
    @site.config['style'].reject {|alt| alt == @style }
  end

  def keys
    @params.keys
  end

  def has_key?(key)
    @params.has_key?(key)
  end

  # return normalized value
  #
  def [](key)
    return nil unless @params.has_key? key
    normalize_parameter(@params[key])
  end

  # plant a fake CGI parameter
  #
  def []=(key, value)
    @params[key] = value
  end

  # return list of normalized values of CGI parameters with given names
  #
  def values_at(keys)
    keys.map {|key| self[key] }
  end

  # return a file object (not its contents), or +nil+ if it's empty or not a
  # file
  #
  def value_file(key)
    file = @params[key]

    if file.kind_of?(Hash) and file.has_key?(:tempfile) and file[:tempfile].size > 0
      limit = @site.config['limit']['content']
      if file[:tempfile].size > limit
        raise UserError, sprintf(
          _('Uploaded file is larger than %s bytes limit'), limit)
      end
      UploadTempfile.new(file[:tempfile], file[:filename])
    else
      nil
    end
  end

  # dump CGI parameters (except passwords) for error report
  #
  def dump_params
    @params.dup.delete_if {|k, v|
      k =~ /^password/
    }.inspect
  end

  # Generate and return action confirmation hash that is used by
  # ApplicationHelper#action_token_field() for CSRF protection. The hash is
  # stored in cache and reused in all secure forms until it is removed upon
  # successful verification.
  #
  def action_token
    @action_token ||= generate_action_token
  end

  # Check CSRF protection prepared by ApplicationHelper#action_token_field().
  #
  # Compares the action token submitted in the form against the one stored in
  # cache, fails automatically for non-POST requests, for guests does nothing
  # and always succeeds. Returns +true+ on success and +false+ on failure.
  #
  # Action token is wiped once used.
  #
  def action_confirmed?
    return false unless 'POST' == @env['REQUEST_METHOD']
    return true unless @session.member

    key = action_token_key
    action_token = self['action_token']
    if action_token and action_token == @site.cache[key]
      @site.cache.delete(key)
      true
    else
      false
    end
  end

  # Report error if action_confirmed?() returns +false+.
  #
  # Invoke this before committing any user-requested changes to the database,
  # but try to do it _after_ validation of all submitted data, to make sure
  # that action token is not cleared until it's no longer needed.
  #
  def assert_action_confirmed
    action_confirmed? or raise AuthError, _('Forged request detected')
  end

  # print header and optionally content, then clean-up and exit
  #
  def response(controller)
    if @notice
      set_cookie('notice', @notice)
    end

    body = compress(controller.render) unless 302 == @status

    unless 304 == @status
      @headers['Content-Type'] ||= 'text/html'
      @headers['Content-Type'] << '; charset=utf-8'
    end

    if body
      @headers['Content-Length'] = Rack::Utils.bytesize(body).to_s
      @headers['Content-Location'] = File.join('', @uri_prefix)
      return [ @status, @headers, [body] ]
    else
      return [ @status, @headers, [] ]
    end
  end

  # Make sure 'redirect_when_done' cookie value is set to a relative location,
  # so that a secure action doesn't redirect back to an unencrypted page.
  #
  # Exception: never redirect back to member/login, redirect to frontpage
  # instead.
  #
  def set_redirect_when_done_cookie
    unless cookie('redirect_when_done')
      set_cookie('redirect_when_done', referer_but_no_login)
    end
  end

  # 'redirect_when_done' cookie overrides value of referer header
  #
  def redirect_when_done
    location = cookie('redirect_when_done')
    if location
      unset_cookie('redirect_when_done')
    else
      location = referer_but_no_login
    end
    redirect(location)
  end

  # send a redirect header and finish the request processing
  #
  # +location+ defaults to referer; site base is prepended to relative links
  #
  def redirect(location = nil)
    if location.nil?
      location = referer
    elsif not absolute_url?(location)
      location = File.join(@base, location.to_s)
    end
    @headers['Location'] = location
    @status = 302
    throw :finish
  end

  # record a notice to be displayed on next request
  #
  def add_notice(notice)
    if @notice
      @notice << notice
    else
      @notice = notice
    end
  end

  def notice
    cookie('notice')
  end

  def reset_notice
    unset_cookie('notice')
  end

  private

  # check size limit, read multipart field into memory, transform empty value
  # to +nil+
  #
  def normalize_parameter(value)
    raise UserError, _('Input size exceeds content size limit') if
      value.respond_to?(:size) and
      value.size > @site.config['limit']['content']

    case value
    when StringIO, Tempfile
      io = value
      value = io.read
      io.rewind
    end

    if value.respond_to?(:encoding)
      value.force_encoding('UTF-8')
      value.valid_encoding? or raise UserError, 'Invalid input encoding'
    end

    (value =~ /[^\s]/) ? value : nil
  end

  def action_token_key
    %{action_token/#{@session.login}}
  end

  def generate_action_token
    return nil unless @session.member

    @site.cache.fetch_or_add(action_token_key) do
      random_digest(@session.login)
    end
  end

  def referer_but_no_login
    location = (referer or '').sub(/\A#{@base}/, '')
    (location.empty? or 'member/login' == location)? '/' : location
  end

  # see #compress
  #
  MIN_GZ_SIZE = 1024

  # do gzip compression and check ETag when supported by client
  #
  def compress(body)
    if body.length > MIN_GZ_SIZE and @env.has_key?('HTTP_ACCEPT_ENCODING')
      enc =
        case @env['HTTP_ACCEPT_ENCODING']
        when /x-gzip/ then 'x-gzip'
        when /gzip/   then 'gzip'
        end
      if enc
        io = StringIO.new
        gz = Zlib::GzipWriter.new(io)
        gz.write(body)
        gz.close
        body = io.string
        @headers['Content-Encoding'] = enc
        @headers['Vary'] = 'Accept-Encoding'
      end
    end

    # check ETag
    if @env.has_key?('HTTP_IF_NONE_MATCH')
      etag = '"' + digest(body) + '"'
      @headers['ETag'] = etag
      @env['HTTP_IF_NONE_MATCH'].split(',').each do |e|
        if etag == e.strip
          @status = 304
          body = nil   # don't send body
          break
        end
      end
    end

    body
  end

  # parse and store user's accept-language preferences, determine the UI
  # language from the results
  #
  def set_language(site_languages, http_accept_language)
    @accept_language = []   # [[lang, q]...]

    if http_accept_language
      http_accept_language.scan(/([^ ,;]+)(?:;q=([^ ,;]+))?/).collect {|l, q|
        [l, (q ? q.to_f : 1.0)]
      }.sort_by {|l, q| -q }.each {|l, q|
        unless site_languages.include? l
          l = normalize_language(l)
        end
        @accept_language.push l if site_languages.include? l
      }
    end

    # set interface language
    self.language =
      if lang = cookie('lang') and site_languages.include?(lang)
        lang   # lang cookie overrides Accept-Language
      elsif @accept_language.empty?
        site_languages.first
      else
        @accept_language.first
      end
  end

  # try converting full locale (language tag) to ISO-639 language only
  #
  # http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.4
  #
  def normalize_language(tag)
    if defined? Locale::Tag
      tag = Locale::Tag.parse(tag).language
    elsif defined? Locale::Object
      tag = Locale::Object.new(tag).language
    end
    tag
  end
end
