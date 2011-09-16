#!/usr/bin/env ruby
#
# Samizdat application helper tests
#
#   Copyright (c) 2002-2009  Dmitry Borodaenko <angdraug@debian.org>
#
#   This program is free software.
#   You can distribute/modify this program under the terms of
#   the GNU General Public License version 3 or later.
#
# vim: et sw=2 sts=2 ts=8 tw=0

require 'test/unit'
require 'rexml/document'
require 'samizdat'
# let mocks overwrite originals
require 'test/mock'
require 'test/util'

require 'samizdat/helpers/application_helper'

class TC_ApplicationHelper < Test::Unit::TestCase
  include ApplicationHelper

  def setup
    # create a dummy session
    @request = MockRequest.new
    @session = @request.session
  end

  def teardown
    @request = nil
    @session = nil
  end

  def test_box_with_title
    root = parse(box('Title', 'Content.'))
    assert_equal 'box', root.attributes['class']
    assert_equal ['Title'], elements(root, '//div[@class="box-title"]')
    assert_equal ['Content.'], elements(root, '//div[@class="box-content"]')
  end

  def test_box_without_title
    root = parse(box(nil, 'Content.'))
    assert_equal [], elements(root, '//div[@class="box-title"]')
    assert_equal ['Content.'], elements(root, '//div[@class="box-content"]')
  end

  def test_form_field_label
    root = parse(form_field(:label, 'some_field', 'Label'))
    assert_equal 'label', root.attributes['class']
    assert_equal ['f_some_field'], elements(root, 'label', 'for')
    assert_equal ['Label'], elements(root, 'label')
  end

  def test_form_field_textarea
    root = parse(form_field(:textarea, 't_a', "Some\nText."))
    assert_equal 't_a', root.attributes['name']
    assert_equal "Some\nText.", root.text.strip
  end

  def test_form_field_select
    root = parse(form_field(:select, 't_select',
      ['a1', ['a2', 'Label 2']]))
    assert_equal 't_select', root.attributes['name']
    assert_equal ['a1'], elements(root, 'option[@value="a1"]')
    assert_equal ['Label 2'], elements(root, 'option[@value="a2"]')
  end

  def test_form_field_submit
    root = parse(form_field(:submit, 't_submit', 'Click'))
    assert_equal 't_submit', root.attributes['name']
    assert_equal 'Click', root.attributes['value']
    assert_equal 'submit', root.attributes['type']
    assert_equal 'submit', root.attributes['class']
  end

  def test_form_field_input
    root = parse(form_field(:password, 'passwd', 'secret'))
    assert_equal 'passwd', root.attributes['name']
    assert_equal 'secret', root.attributes['value']
    assert_equal 'password', root.attributes['type']
  end

  def test_form
    root = parse(form('member/login', [:password, 'passwd'], [:submit]))
    assert_equal '/member/login', root.attributes['action']
    assert_equal 'post', root.attributes['method']
    assert_equal ['password', 'submit'], elements(root, 'div/input', 'type')
  end

  def test_form_with_file
    root = parse(form('message/publish', [:file, 't_file']))
    assert_equal '/message/publish', root.attributes['action']
    assert_equal 'post', root.attributes['method']
    assert_equal 'multipart/form-data', root.attributes['enctype']
    assert_equal ['file'], elements(root, 'div/input', 'type')
  end
end
