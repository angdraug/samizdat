# Samizdat profile field plugin superclass
#
#   Copyright (c) 2002-2009  Dmitry Borodaenko <angdraug@debian.org>
#
#   This program is free software.
#   You can distribute/modify this program under the terms of
#   the GNU General Public License version 3 or later.
#
# vim: et sw=2 sts=2 ts=8 tw=0

require 'samizdat'

class ProfilePlugin < Plugin
  def api
    'profile'
  end

  def match?(name)
    fields.include?(name)
  end

  def fields
    []
  end

  # translated field label
  #
  def label(field)
  end

  # validate and normalize field values, raise UserError if value is invalid
  #
  def validate(request)
    fields.each do |field|
      request[field] = normalize(field, request[field]) if request[field]
    end
  end

  def normalize(field, value)
    value
  end

  def load_fields(member)
    fields.each do |field|
      member.profile[field] = member.preferences[field]
    end
  end

  def form_fields(member)
    fields.collect {|field|
      [ [ :label, field, label(field) ],
        [ :text, field, member.profile[field] ] ]
    }.flatten(1)
  end

  # update the values of profile fields, return a notice for each changed value
  #
  def update(member, request)
    validate(request)
    fields.collect do |field|
      value = request[field]
      if value != member.profile[field]
        if value.nil?
          member.preferences.delete(field)
        else
          member.preferences[field] = value
        end
        sprintf(_('%s updated'), label(field))
      end
    end
  end
end
