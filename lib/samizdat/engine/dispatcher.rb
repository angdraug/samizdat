# Samizdat dispatcher classes
#
#   Copyright (c) 2002-2009  Dmitry Borodaenko <angdraug@debian.org>
#
#   This program is free software.
#   You can distribute/modify this program under the terms of
#   the GNU General Public License version 3 or later.
#
# vim: et sw=2 sts=2 ts=8 tw=0

require 'samizdat'

class Route
  ROUTE_PATTERN = Regexp.new(
    %r{\A
      /
      ([[:alpha:]][[:alnum:]_]*)
      (?:
        /([0-9]+)
      )?
      (?:
        /([[:alpha:]][[:alnum:]_]*)
      )?
      (?:
        /
      )?
    \z}x
  ).freeze

  DEFAULT_CONTROLLER = 'frontpage'
  DEFAULT_ACTION = :index

  RESOURCE_ROUTE_PATTERN = Regexp.new(%r{\A/([0-9]+)\z}).freeze
  RESOURCE_CONTROLLER = 'resource'

  def initialize(request)
    request.site.plugins.find_all('route', request) do |plugin|
      plugin.rewrite(request)
    end

    if '/' == request.route
      @controller = DEFAULT_CONTROLLER
      @action = DEFAULT_ACTION
      return
    end

    match = RESOURCE_ROUTE_PATTERN.match(request.route)
    if match
      @controller = RESOURCE_CONTROLLER
      @id = match[1].to_i.untaint
      @action = DEFAULT_ACTION
      return
    end

    match = ROUTE_PATTERN.match(request.route)
    if match.nil?
      raise ResourceNotFoundError, request.route.to_s
    end

    @controller, @id, @action = match[1..3]
    @controller.untaint

    if @id
      @id = @id.to_i.untaint
    end

    if @action
      if Controller.instance_methods(false).include?(@action)
        # methods defined in Controller class are not valid actions
        raise ResourceNotFoundError, request.route.to_s
      end
      @action = @action.untaint.to_sym
    end

    @action ||= DEFAULT_ACTION
  end

  attr_reader :controller, :id, :action

  # return controller object if controller and action are recognized, raise 404
  # exception otherwise
  #
  def create_controller(request)
    begin
      require %{samizdat/controllers/#{@controller}_controller}
    rescue LoadError
      raise ResourceNotFoundError, @controller
    end

    controller = Object.const_get(
      @controller.gsub(/(?:\A|_+)([^_])/) { $1.capitalize } + 'Controller'
    ).new(request, @id)
    # don't rescue NameError here, it's too generic; if the controller file is
    # there, it should have a class with matching name; if it doesn't, internal
    # error should be raised anyway

    controller.respond_to?(@action) or raise ResourceNotFoundError,
      File.join(@controller, @id.to_s, @action.to_s)

    controller
  end
end

module Dispatcher
  def Dispatcher.render(request, route)
    controller = route.create_controller(request)
    controller.send(route.action)
    controller.render
  end

  def Dispatcher.render_error(request, error)
    controller = ErrorController.new(request)
    controller._error(error)
    controller.render
  end

  # invoke controller action matching the CGI request
  #
  # throw +:finish+ to interrupt the request processing and return to the
  # dispatcher
  #
  def Dispatcher.dispatch(cgi)
    catch :finish do
      request = Request.new(cgi)
      begin
        begin
          Dispatcher.render(request, Route.new(request))

        rescue DRb::DRbConnError => error
          # todo: try to re-establish the lost connection and retry
          raise
        rescue DBI::ProgrammingError, DBI::OperationalError => error
          if 'server closed the connection unexpectedly' == error.message
            # todo: try to re-establish the lost connection and retry
          end
          raise
        end

      rescue => error
        Dispatcher.render_error(request, error)
      end
    end
  end
end
