# Samizdat email blacklist spam protection plugin
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

class EmailBlacklistPlugin < SpamPlugin
  register_as 'email_blacklist'

  def check_email(email)
    entry = blacklist.detect {|bl| email =~ bl } and raise SpamError,
      sprintf(_("The email address you have specified matches blacklist entry " +
                "'%s' and cannot be used for registration"), entry.inspect)
  end

  private

  def blacklist
    @blacklist ||=
      if @options['blacklist'].respond_to?(:collect)
        @options['blacklist'].collect do |entry|
          entry.kind_of?(Regexp)? entry : Regexp.new(Regexp.escape(entry))
        end
      else
        []
      end
  end
end
