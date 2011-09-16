#!/usr/bin/env ruby
#
# Samizdat test suite utility methods
#
#   Copyright (c) 2002-2009  Dmitry Borodaenko <angdraug@debian.org>
#
#   This program is free software.
#   You can distribute/modify this program under the terms of
#   the GNU General Public License version 3 or later.
#
# vim: et sw=2 sts=2 ts=8 tw=0

require 'rexml/document'
require 'rexml/xpath'

XHTML_NS = { 'h' => 'http://www.w3.org/1999/xhtml' }

def elements(element, path, attribute=nil)
  REXML::XPath.match(element, path, XHTML_NS).collect {|e|
    attribute ? e.attributes[attribute] : e.text.strip
  }
end

def text(element, path)
  REXML::XPath.match(element, path, XHTML_NS).collect {|e|
    e.texts.join.strip
  }.join
end

def parse(html)
  begin
    doc = REXML::Document.new(html)
  rescue REXML::ParseException
    assert false, "REXML raised #{$!.class}: #{$!}"
  end
  doc.root
end
