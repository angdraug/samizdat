# Samizdat dispatcher classes
#
#   Copyright (c) 2002-2011  Dmitry Borodaenko <angdraug@debian.org>
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
      @action = @action.untaint.to_sym
      if Controller.method_defined?(@action)
        # methods defined in Controller class are not valid actions
        raise ResourceNotFoundError, request.route.to_s
      end
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

class Dispatcher
  # provide Rack application API
  #
  # invoke controller action matching the request
  #
  # throw +:finish+ to interrupt the request processing and return to the
  # dispatcher
  #
  def call(env)
    request = Request.new(env)
    begin
      render(request, Route.new(request))
    rescue => error
      render_error(request, error)
    end
  end

  private

  def render(request, route)
    controller = route.create_controller(request)
    catch :finish do
      controller.send(route.action)
    end
    request.response(controller)
  end

  def render_error(request, error)
    controller = ErrorController.new(request)
    controller._error(error)
    request.response(controller)
  end
end
