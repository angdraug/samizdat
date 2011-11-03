# Samizdat engine helper functions
#
#   Copyright (c) 2002-2011  Dmitry Borodaenko <angdraug@debian.org>
#
#   This program is free software.
#   You can distribute/modify this program under the terms of
#   the GNU General Public License version 3 or later.
#
# vim: et sw=2 sts=2 ts=8 tw=0

require 'samizdat'
require 'yaml'

module Kernel

# debug output
#
def log(msg)
  log = STDERR
  log << 'Samizdat: ' << msg << "\n"
  log.flush
end

# log a verbose report on exception, return unique error id that can be used to
# find this report in the log
#
def log_exception(error, request = nil)
  error_id = digest(Time.now.to_s + rand.to_s)

  error_report = Time.now.to_s +
    %{: #{error.class}: #{error.to_s}\nError ID: #{error_id}\n}
  error_report << %{Site: #{request.site.name}\n} if request.respond_to?(:site)
  error_report << %{Route: #{request.route}\n} if request.respond_to?(:route)
  error_report << %{CGI parameters: #{@request.dump_params}\n} if
    request.respond_to?(:dump_params)
  error_report << %{Backtrace:\n#{error.backtrace.join("\n")}\n} if
    error.respond_to?(:backtrace)

  log(error_report)
  error_id
end

# expire timeout for permanent cookie
#
def forever
  60 * 60 * 24 * 365 * 5   # 5 years
end

# generate uniform hash
#
def digest(value)
  Digest::MD5.hexdigest(value)   # todo: configurable digest function
end

# generate a random hash from a given seed
#
def random_digest(seed = '')
  digest(seed.to_s + Time.now.to_s + rand().to_s)
end

# parse YAML data or return empty hash
#
def yaml_hash(yaml)
  YAML.load(yaml.to_s) or {}
end

# helper method to load YAML data from file
#
def load_yaml_file(filename, trusted = false)
  File.open(filename) {|f| YAML.load(trusted ? f.read.untaint : f) }
end

# check for readable file in all directories in sequence, return the first one
# found or nil
#
def find_file(file, dirs)
  if found = dirs.find {|dir| File.readable?(File.join(dir, file)) }
    File.join(found, file)
  end
end

# Squish condition to exclude hidden messages
#
def exclude_hidden(node)
  "(s::hidden #{node} ?hidden FILTER ?hidden = 'false')"
end

# true if _url_ can be an absolute URL (i.e. contains scheme component)
#
def absolute_url?(url)
  url.to_s.include?(':')
end

SIZE_UNITS = [
  [ 'K', 1024 ],
  [ 'M', 1024 ** 2 ],
  [ 'G', 1024 ** 3 ],
  [ 'T', 1024 ** 4 ],
  [ 'P', 1024 ** 5 ]
]

def display_file_size(size)
  return '' unless size.kind_of? Numeric

  SIZE_UNITS.each do |name, multiplier|
    display = size.to_f / multiplier

    if display < 1
      return sprintf("%1.2f#{name}", display)

    elsif display < 10
      return sprintf("%1.1f#{name}", display)

    elsif display < 1024 or name == SIZE_UNITS[-1][0]
      return sprintf("%1.0f#{name}", display)
    end
  end
end

LINK_ATTRIBUTE = { 'a' => 'href', 'img' => 'src' }

end

include Kernel
