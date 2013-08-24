#!/usr/bin/env ruby
#
# Samizdat equation generator test
#
#   Copyright (c) 2002-2011  Dmitry Borodaenko <angdraug@debian.org>
#
#   This program is free software.
#   You can distribute/modify this program under the terms of
#   the GNU General Public License version 3 or later.
#
# vim: et sw=2 sts=2 ts=8 tw=0

require 'test/unit'
require 'samizdat/captcha/equation'

class TC_Equation < Test::Unit::TestCase
  def test_add
    eq = Equation.new([20, 2], [:+, '+'])
    assert_equal eq.result, 22
    assert_equal eq.to_s, '20+2'
  end

  def test_mul
    eq = Equation.new([20, 2], [:*, '\u00d7'])
    assert_equal eq.result, 40
    assert_equal eq.to_s, '20\u00d72'
  end

  def test_sub
    eq = Equation.new([20, 2], [:-, '-'])
    assert_equal eq.result, 18
    assert_equal eq.to_s, '20-2'
  end

  def test_div
    eq = Equation.new([20, 2], [:/, ':'])
    assert_equal eq.result, 10
    assert_equal eq.to_s, '20:2'
  end
end

