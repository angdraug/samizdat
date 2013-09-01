#!/usr/bin/env ruby
#
# Samizdat functional regression test
#
#   Copyright (c) 2002-2011  Dmitry Borodaenko <angdraug@debian.org>
#
#   This program is free software.
#   You can distribute/modify this program under the terms of
#   the GNU General Public License version 3 or later.
#
# vim: et sw=2 sts=2 ts=8 tw=0

ENV['SAMIZDAT_SITE'] ||= 'samizdat'
ENV['SAMIZDAT_URI'] ||= '/'
ENV['SAMIZDAT_HOST'] ||= 'http://samizdat'

require 'test/unit'
require 'net/http'
require 'uri'
require 'rexml/document'
require 'test/util'
require 'samizdat'

# WARNING: this test will DESTROY DATA in your samizdat database!
#
# it assumes that samizdat database is empty: if you have any data in your
# site, back it up and recreate a clean database using database/*.sql
#
class TC_Robot < Test::Unit::TestCase
  STAMP = Time.new.to_i.to_s

  def setup
    @site = Site.new(ENV['SAMIZDAT_SITE'])
    @host = (ENV['SAMIZDAT_HOST'] or 'http://localhost')
    @base = URI.parse(@host + ENV['SAMIZDAT_URI'])
    @login = 'test' + STAMP
    @full_name = 'Test' + STAMP
    @email = 'test' + STAMP + '@localhost'
    @password = 'test'
  end

  def teardown
    @base, @login, @full_name, @email, @password = nil
  end

  # order-sensitive tests

  def test_00_anonymous
    # load front page
    assert_equal Net::HTTPOK, (response = get('')).class
    root = parse(response.body)
    # test version
    version, = elements(root,
      '/h:html/h:head/h:meta[@name="generator"]', 'content') 
    assert version.gsub!(/^Samizdat\s+/, '')
    assert_equal SAMIZDAT_VERSION, version
    # look for login form
    login_form, = elements(root,
      '//h:div[@id="subhead"]/h:div/h:a[2]', 'href')
    assert_equal 'member/login', login_form

    # test anonymous check on publish
    response = get('message/publish')
    assert_equal Net::HTTPUnauthorized, response.class
    root = parse(response.body)
    assert_equal ['Access Denied'], elements(root,
      '//h:div[@id="main"]/h:div/h:div[@class="box-title"]')
  end

  def test_01_member
    response = post('member/create_account',
      "login=#{@login}&email=#{@email}&password1=#{@password}&password2=#{@password}&submit",
      {'Referer' => @base.path})
    case response
    when Net::HTTPOK
      root = parse(response.body)
      assert_equal ['User Error'], elements(root,
        '//h:div[@id="main"]/h:div/h:div[@class="box-title"]')
      print 'test login already exists'
    when Net::HTTPFound
      assert @@session = response['set-cookie']
      assert_equal @base.to_s + 'member/profile', response['location']

      # check if valid session is reflected in subhead
      response = get('', {'Cookie' => @@session})
      assert_equal Net::HTTPOK, response.class
      root = parse(response.body)
      assert_equal @login, elements(root,
        '//h:div[@id="subhead"]/h:div/h:a[1]')[0]
    else
      assert false, 'Unexpected HTTP code'
    end

    # todo: test checks for duplicates
  end

  def test_02_login
    # test if login fails with wrong passwd
    response = post 'member/login', "login=#{@login}&password=#{@password}wrong"
    assert_equal nil, response['set-cookie']

    # try to login with correct passwd
    response = post 'member/login', "login=#{@login}&password=#{@password}"
    assert @@session = response['set-cookie']

    # extract member id
    response = get('', {"Cookie" => @@session})
    assert @@session = response['set-cookie']
    assert_equal Net::HTTPOK, response.class
    root = parse(response.body)
    blog_link, = elements(root,
      '//h:div[@id="subhead"]/h:div/h:a[1]', 'href')
    assert_equal 'blog/' + @login, blog_link
  end

  def test_03_message
    # post message
    title, body = 'Test Message 1', 'blah blah'
    response = publish_message(title, body)

    assert_equal Net::HTTPFound, response.class
    assert id = response['location'].sub(@base.to_s, '')
    assert(id.to_i > 0, "Unexpected redirect location '#{response['location']}'")
    assert_equal Net::HTTPOK, (response = get(id)).class
    msg = REXML::XPath.first(parse(response.body),
      '//h:div[@id="main"]/h:div', XHTML_NS)
    assert_equal title, text(msg, %{//h:div[@class="box-title"]})
    assert_equal body, elements(msg,
      '//h:div[@class="content"]/h:p').join.strip

    # post plain text reply
    body = "plain\ntext"
    response = publish_message(title, body, id, 'text/plain')

    assert @@session = response['set-cookie']
    assert_equal Net::HTTPFound, response.class
    assert id2 = response['location'].gsub(/^.*#id/, '')
    assert_equal Net::HTTPOK, (response = get(id2)).class
    assert msg = REXML::XPath.first(parse(response.body),
      '//h:div[@id="main"]/h:div', XHTML_NS)
    assert_equal title, text(msg, %{//h:div[@class="box-title"]})
    assert_equal body, elements(msg,
      '//h:div[@class="content"]/h:pre').join.strip

    # todo: test missing title or body
    # todo: publish query (test_query)
    # todo: test file upload
  end

  def test_04_resource
    # test 404 on nonexistent resoource
    assert_equal Net::HTTPNotFound, (response = get('resource')).class

    # get a test resource
    assert (response = get('')).kind_of?(Net::HTTPSuccess)
    main = REXML::XPath.first(parse(response.body),
      '//h:div[@id="main"]', XHTML_NS)
    assert msg = REXML::XPath.first(main,
      %{//h:div[@class="info"]/h:a[@href="blog/#{@login}"]/../..}, XHTML_NS)
    assert id = elements(msg, 'h:div[@class="title"]/h:a', 'href')[0]

    # post test tag resource
    title, body = 'Test Tag', 'test tag'
    response = publish_message(title, body)
    assert @@session = response['set-cookie']
    assert_equal Net::HTTPFound, response.class
    assert @@tag_id = response['location'].sub(@base.to_s, '')

    # test anonymous check for vote
    response = post("resource/#{id}/vote",
      "tag=#{@@tag_id}&rating=2")
    assert_equal Net::HTTPUnauthorized, response.class
    root = parse(response.body)
    assert_equal ['Access Denied'], elements(root,
      '//h:div[@id="main"]/h:div/h:div[@class="box-title"]')

    # vote on rating
    response = get("resource/#{id}/vote", {"Cookie" => @@session})
    assert action_token = get_action_token(response)
    response = post("resource/#{id}/vote",
      "tag=#{@@tag_id}&action_token=#{action_token}&rating=1",
      {"Cookie" => @@session, "Referer" => @base.path + id})
    assert_equal Net::HTTPFound, response.class
    assert_equal id, response['location'].sub(@base.to_s, '')
    assert_equal Net::HTTPOK, (response = get(id)).class
    root = parse(response.body)
    assert_equal [': 1.00'], elements(root,
      %{//h:div[@id="tags"]/h:div[@class="box-content"]/h:p[1]})
  end

  def test_05_stress
    title, body = 'Test Thread', '.'
    response = publish_message(title, body)
    parent = thread = response['location'].sub(@base.to_s, '')
    count = 5   # increase if you have time to wait
    while count > 0 do
      title, body = 'Test Message ' + count.to_s, 'blah blah.'
      response = publish_message(title, body, parent)
      assert @@session = response['set-cookie']
      assert_equal Net::HTTPFound, response.class
      parent = response['location'].sub(/#.*$/, '').sub(@base.to_s, '')
      response = get("resource/#{parent}/vote", {"Cookie" => @@session})
      assert action_token = get_action_token(response)
      response = post("resource/#{parent}/vote",
        "tag=#{@@tag_id}&rating=1",
        {"Cookie" => @@session, "Referer" => @base.path + parent})
      @@session = response['set-cookie']
      count = count - 1
    end
  end

  def test_06_escape_title
    response = publish_message(%q{Test '}, '.') do |preview_response|
      msg = REXML::XPath.first(parse(preview_response.body),
        '//h:div[@id="main"]/h:div', XHTML_NS)
      assert_equal %q{Test &#x27;}, text(msg, %{//h:div[@class="box-title"]})
    end
    id = response['location'].sub(@base.to_s, '')
    assert_equal Net::HTTPOK, (response = get(id)).class
    msg = REXML::XPath.first(parse(response.body),
      '//h:div[@id="main"]/h:div', XHTML_NS)
    assert_equal %q{Test &#x27;}, text(msg, %{//h:div[@class="box-title"]})

    assert (response = get('')).kind_of?(Net::HTTPSuccess)
    main = REXML::XPath.first(parse(response.body),
      '//h:div[@id="main"]', XHTML_NS)
    assert msg = REXML::XPath.first(main,
      %{//h:div[@class="info"]/h:a[@href="blog/#{@login}"]/../..}, XHTML_NS)
    assert_equal %q{Test &#x27;}, text(msg, 'h:div[@class="title"]/h:a')
  end

  def test_07_edit_message
    response = publish_message('Test Edit', 'Version 1')
    id = response['location'].sub(@base.to_s, '')
    assert_equal Net::HTTPOK, (response = get(id)).class
    msg = REXML::XPath.first(parse(response.body),
      '//h:div[@id="main"]/h:div', XHTML_NS)
    assert_equal 'Version 1', elements(msg,
      '//h:div[@class="content"]/h:p').join.strip

    response = publish_message('Test Edit', 'Version 2', id, nil, 'edit')
    assert_equal id, response['location'].sub(@base.to_s, '')
    assert_equal Net::HTTPOK, (response = get(id)).class
    msg = REXML::XPath.first(parse(response.body),
      '//h:div[@id="main"]/h:div', XHTML_NS)
    assert_equal 'Version 2', elements(msg,
      '//h:div[@class="content"]/h:p').join.strip
  end

  def test_08_translate_message
    response = publish_message('Test Translate', 'English')
    id = response['location'].sub(@base.to_s, '')
    assert_equal Net::HTTPOK, (response = get(id)).class
    msg = REXML::XPath.first(parse(response.body),
      '//h:div[@id="main"]/h:div', XHTML_NS)
    assert_equal 'English', elements(msg,
      '//h:div[@class="content"]/h:p').join.strip

    response = publish_message('Test Translate', 'Belarusian', id, nil, 'translate', 'be')
    assert translation = response['location'].sub(@base.to_s, '')
    assert_equal Net::HTTPOK, (response = get(translation)).class
    msg = REXML::XPath.first(parse(response.body),
      '//h:div[@id="main"]/h:div', XHTML_NS)
    assert_equal 'Belarusian', elements(msg,
      '//h:div[@class="content"]/h:p').join.strip

    assert_equal Net::HTTPOK, (response = get(id)).class
    msg = REXML::XPath.first(parse(response.body),
      '//h:div[@id="main"]/h:div', XHTML_NS)
    assert_equal 'be', elements(msg, '//h:div[@class="info"]/h:a[2]').join.strip
  end

  def test_09_tags
    response = get('tags')
    assert_equal Net::HTTPOK, response.class
    body = REXML::XPath.first(parse(response.body),
      '//h:div[@id="main"]/h:div', XHTML_NS)
    assert_equal 'Tag', elements(body, '//h:th[1]').join.strip
    assert_equal 'Related Resources', elements(body, '//h:th[2]').join.strip
  end

  def test_10_moderation
    response = get('moderation')
    body = REXML::XPath.first(parse(response.body),
      '//h:div[@id="main"]/h:div', XHTML_NS)
    assert_equal ['Links', 'Moderation Log'],
      elements(body, '//h:div[@class="box-title"]')
  end

  # todo: test pagination

  private

  # utility methods

  def post(action, data, header={})
    Net::HTTP.start(@base.host) do |http|
      http.post(@base.path + action, data, header)
    end
  end

  def get(action, header={})
    response = Net::HTTP.start(@base.host) do |http|
      http.get(@base.path + action, header)
    end
    sleep 0.001
    response
  end

  def get_action_token(response)
    elements(parse(response.body),
      '//h:input[@name="action_token"]', 'value')[0]
  end

  def publish_message(title, body, parent = nil, format = nil, action = 'reply', lang = 'en')
    if parent
      route = "message/#{parent}/#{action}"
    else
      route = "message/publish"
    end
    params = "title=#{Rack::Utils.escape(title)}&body=#{Rack::Utils.escape(body)}&lang=#{lang}"
    params << "&format=#{format}" if format
    preview_response = post(route, params + "&preview", {"Cookie" => @@session})
    if block_given?
      yield preview_response
    end
    action_token = get_action_token(preview_response)
    post(route, params + "&action_token=#{action_token}&confirm", {"Cookie" => @@session})
  end
end
