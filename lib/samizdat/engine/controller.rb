# Samizdat controller class
#
#   Copyright (c) 2002-2011  Dmitry Borodaenko <angdraug@debian.org>
#
#   This program is free software.
#   You can distribute/modify this program under the terms of
#   the GNU General Public License version 3 or later.
#
# vim: et sw=2 sts=2 ts=8 tw=0

require 'samizdat'
require 'samizdat/helpers/application_helper'

class Controller
  include ApplicationHelper

  def initialize(request, id=nil)
    self.request = request

    @id = id

    @layout = 'page_layout.rhtml'
    @template = default_template

    @title = nil
    @content_for_layout = nil

    # rss feeds
    @feeds = {}

    # document navigation links (made, start, next, ...)
    @links = { :start => @request.base,
               :icon => config['site']['icon'] }

    # JavaScript libraries
    @js = [ 'flashembed' ]
  end

  def render
    @content_for_layout ||= render_template(@template)

    if @cache_key
      cache[@cache_key] = @content_for_layout
    end

    if @request.notice
      @content_for_layout =
        '<div class="notice">' + @request.notice + '</div>' +
        @content_for_layout
      @request.reset_notice
    end

    @layout ? render_template(@layout) : @content_for_layout
  end

  private

  def default_template
    self.class.to_s.sub(/Controller\z/, '').downcase + '.rhtml'
  end

  def render_template(template)
    View.cached(@request.site, template).render(binding)
  end

  # check if moderatorial action is allowed
  #
  def assert_moderate
    @member.assert_allowed_to('moderate')
  end

  # log moderatorial action (run inside transaction)
  #
  def log_moderation(action)
    (@session.member and @id) or raise RuntimeError,
      'Not enough data to log moderation'

    db[:Moderation].insert(
      :moderator => @session.member,
      :action => action,
      :resource => @id
    )
  end

  # Check if page body (@content_for_layout) is found in the cache under _key_.
  # If it is found, return +true+ to indicate that no further processing of the
  # controller action is necessary. Otherwise, return +false+ to indicate that
  # page body has to be generated, and save _key_ so that the body can be
  # cached later.
  #
  def try_cache(key)
    key += '/' + @request.uri_prefix + '/' + @request.accept_language.join(':')
    if body = cache[key]
      @content_for_layout = body
      return true
    else
      @cache_key = key
      return false
    end
  end
end

# generate error page on exceptions
#
class ErrorController < Controller
  def _error(error)
    case error
    when AuthError
      @request.status = 401
      @title = _('Access Denied')
      @content_for_layout = %{<p>#{error}.</p>}

    when AccountBlockedError
      @title = _('Account Is Blocked')
      @content_for_layout = %{<p>#{error}</p>}

    when UserError
      @title = _('User Error')
      @content_for_layout =
%{<p>#{error}.</p><p>}+_("Press 'Back' button of your browser to return.")+'</p>'

    when ResourceNotFoundError
      @request.status = 404
      @title = _('Resource Not Found')
      if referer = @request.referer
        referer = sprintf(_(' (looks like it was %s)'), %{<a href="#{referer}">#{referer}</a>})
      end
      @content_for_layout =
'<p>' + sprintf(_('The resource you requested (%s) was not found on this site. Please report this error back to the site you came from%s.'), Rack::Utils.escape_html(error.message), referer.to_s) + '</p>'

    else
      error_id = log_exception(error, @request)

      @request.status = 500
      @title = _('Runtime Error')
      @content_for_layout =
'<p>'+_('Runtime error has occured.')+%{ Error ID: #{Rack::Utils.escape_html(error_id)}.</p>
<p>}+_('Please report this error to the site administrator.')+'</p>'
    end

    @content_for_layout = box(@title, @content_for_layout)
  end
end
