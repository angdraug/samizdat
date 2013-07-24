# Samizdat regexp merge spam filtering plugin
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

class SpamMergePlugin < SpamPlugin
  register_as 'spam_merge'

  def check_text(role, text)
    return unless regexp_list.kind_of?(Enumerable) and @roles.include?(role)

    regexp_list.each do |re|
      text =~ re and raise SpamError, _('Your message looks like spam')
    end
  end

  private

  def regexp_list
    return nil if @roles.empty?
    @regexp_list ||= shared_cache.fetch_or_add(
      'samizdat/*/spam_merge/' + site.name
    ) { load_regexp_list }
  end

  def load_regexp_list
    if @options['exclude'].kind_of? Array
      exclude = Regexp.new(
        @options['exclude'].collect {|s| Regexp.escape(s) }.join('|')
      ).freeze
    end

    begin
      Kernel.open(@options['url'].untaint) {|f| f.read }

    rescue => error
      log_exception(error)

      # default to 68-char "GTUBE" spamstring, see
      # http://spamassassin.apache.org/gtube/
      'XJS\*C4JDBQADN1\.NSBN3\*2IDNEN\*GTUBE-STANDARD-ANTI-UBE-TEST-EMAIL\*C\.34X'
    end.split(/[\r\n]+/).collect do |line|
      line.gsub!(/\s*#.*\z/, '')
      if line.size > 6 and
        line !~ /\(\?\</ and     # (?< ) not supported in Ruby
        line !~ /^[^\[]*\]/ and   # ] w/o matching [ triggers a warning from Ruby
        (exclude.nil? or line !~ exclude)

        line
      end
    end.compact.collect do |line|
      Regexp.new(line).freeze
    end
  end
end
