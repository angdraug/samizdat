#!/usr/bin/env ruby
#
# Samizdat password encryption tests
#
#   Copyright (c) 2002-2009  Dmitry Borodaenko <angdraug@debian.org>
#
#   This program is free software.
#   You can distribute/modify this program under the terms of
#   the GNU General Public License version 3 or later.
#
# vim: et sw=2 sts=2 ts=8 tw=0

require 'test/unit'
require 'samizdat'

class TC_Password < Test::Unit::TestCase
  def test_random
    p = Password.random
    assert_kind_of String, p
    assert_equal false, p.empty?
  end

  def test_encrypt
    hash = Password.encrypt(Password.random)
    assert_kind_of String, hash
    assert_equal false, hash.empty?
  end

  def test_check
    p = Password.random
    hash = Password.encrypt(p)
    assert Password.check(p, hash)
  end

  def test_check_digest
    p = Password.random
    hash = digest(p)
    assert Password.check(p, hash)
  end
end
