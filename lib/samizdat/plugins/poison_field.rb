# Samizdat poison field spam protection plugin
#
#   Copyright (c) 2002-2011  Dmitry Borodaenko <angdraug@debian.org>
#
#   This program is free software.
#   You can distribute/modify this program under the terms of
#   the GNU General Public License version 3 or later.
#
# vim: et sw=2 sts=2 ts=8 tw=0

require 'samizdat'
require 'samizdat/plugins/spam'

class PoisonFieldPlugin < SpamPlugin
  register_as 'poison_field'

  def add_message_fields(request)
    return [] unless @roles.include? request.role
    %{<input name="#{field_name}" style="display:none" type="text" />\n}
  end

  def check_message_fields(request)
    return unless @roles.include? request.role
    request[field_name] and raise SpamError,
      _('You have filled in a field intended for spam bots')
  end

  private

  def field_name
    'email'
  end
end
