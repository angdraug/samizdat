# Samizdat time handling
#
#   Copyright (c) 2002-2011  Dmitry Borodaenko <angdraug@debian.org>
#
#   This program is free software.
#   You can distribute/modify this program under the terms of
#   the GNU General Public License version 3 or later.
#
# vim: et sw=2 sts=2 ts=8 tw=0

require 'time'
require 'date'

# add to_time() to String and DateTime if it's not there
unless String.method_defined? 'to_time'
  class String
    def to_time
      Time.parse(self)
    end
  end
end

unless DateTime.method_defined? 'to_time'
  class DateTime
    def to_time
      Time.parse(self.to_s)
    end
  end
end

unless Time.method_defined? 'to_time'
  class Time
    def to_time
      self
    end
  end
end
