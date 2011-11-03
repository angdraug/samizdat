# Samizdat occupation profile field plugin
#
#   Copyright (c) 2002-2011  Dmitry Borodaenko <angdraug@debian.org>
#
#   This program is free software.
#   You can distribute/modify this program under the terms of
#   the GNU General Public License version 3 or later.
#
# vim: et sw=2 sts=2 ts=8 tw=0

require 'samizdat'
require 'samizdat/plugins/profile'

class OccupationPlugin < ProfilePlugin
  def fields
    ['occupation']
  end

  def label(field)
    {'occupation' => _('Occupation')}[field]
  end
end

PluginClasses.instance['occupation'] = OccupationPlugin
