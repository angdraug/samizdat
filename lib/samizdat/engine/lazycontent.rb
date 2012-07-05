# Samizdat time handling
#
#   Copyright (c) 2002-2011  Dmitry Borodaenko <angdraug@debian.org>
#
#   This program is free software.
#   You can distribute/modify this program under the terms of
#   the GNU General Public License version 3 or later.
#
# vim: et sw=2 sts=2 ts=8 tw=0

class LazyContent
  include Enumerable

  def initialize request
    @request = request
    @content = []
  end

  def each
    @content.each_with_index {|a,i| yield(@content[i]=force_val(a)) }
  end

  def to_s
    force.to_s
  end

  def join separator=$,
    force.join(separator)
  end

  def force
    map{|x| x}
  end

  def method_missing method, *args, &block
    @content.__send__(method, *args, &block)
    self
  end

private
  def force_val a
    a.kind_of?(Proc) ? a.call(@request) : a
  end
end

class Array
  alias old_plus +
  def + obj
    obj.kind_of?(LazyContent) ? obj + self : old_plus(obj)
  end
end
