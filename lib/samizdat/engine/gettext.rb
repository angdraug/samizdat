# Samizdat gettext l10n setup
#
#   Copyright (c) 2002-2009  Dmitry Borodaenko <angdraug@debian.org>
#
#   This program is free software.
#   You can distribute/modify this program under the terms of
#   the GNU General Public License version 3 or later.
#
# vim: et sw=2 sts=2 ts=8 tw=0

module Kernel

# try to initialize FastGettext
begin
  require 'fast_gettext'

  include FastGettext::Translation

  def samizdat_bindtextdomain(locale, path=nil)
    FastGettext.add_text_domain('samizdat', :path => (path or '/usr/share/locale'))
    FastGettext.text_domain = 'samizdat'
    FastGettext.locale = locale
  end

rescue LoadError
  # try to fall back to GetText
  begin
    require 'gettext'

    GetText.module_eval do
      #:nodoc: all source files and classes are equal
      def callersrc
        "samizdat"   # hack for GetText < 1.6.0
      end
      def bound_target(klass = nil)
        Object   # hack for GetText >= 1.6.0
      end
    end

    include GetText

    # workaround for API change in GetText 1.6.0
    major, minor = GetText::VERSION.split('.').collect {|i| i.to_i }
    if major < 1 or (1 == major and minor < 6) then
      # GetText < 1.6.0
      def samizdat_bindtextdomain(locale, path=nil)
        bindtextdomain('samizdat', path, locale, 'utf-8')
      end
    elsif major < 2
      # GetText < 2.0.0
      def samizdat_bindtextdomain(locale, path=nil)
        GetText::bindtextdomain('samizdat',
          :locale => locale,
          :charset => 'utf-8',
          :path => path)
      end
    else
      def samizdat_bindtextdomain(locale, path=nil)
        GetText::bindtextdomain('samizdat',
          :charset => 'utf-8',
          :path => path)
        GetText::set_locale(locale)
      end
    end
    major, minor = nil

  rescue LoadError
    def _(msgid)
      msgid
    end

    def samizdat_bindtextdomain(locale, path=nil)
    end
  end
end

end

include Kernel
