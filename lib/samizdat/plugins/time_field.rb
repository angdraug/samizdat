# vim: et sw=2 sts=2 ts=8 tw=0

require 'samizdat'
require 'samizdat/plugins/spam'
require 'time'

class TimeFieldPlugin < SpamPlugin

  DEFAULT_DELAY = 60

  def initialize(*args)
    super *args

    @delay =
    begin
      config['plugins']['options']['spam']['post_delay']
    rescue
    end
    @delay ||= DEFAULT_DELAY
  end

  def add_message_fields(request)
    return [] unless @roles.include? request.role
    %{<input name="#{field_name}" type="hidden" value="#{(Time.now + @delay).to_i}"/>\n}
  end

  def check_message_fields(request)
    return unless @roles.include? request.role
    request[field_name].to_i > Time.now.to_i and raise SpamError,
      _('You are posting too fast. Are you spam bot?')
  end

  private

  def field_name
    'fa021ae862f528e719dcdddb069eefd5'
  end
end

PluginClasses.instance['time_field'] = TimeFieldPlugin
