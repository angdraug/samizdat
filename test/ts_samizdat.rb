#!/usr/bin/env ruby
#
# Samizdat storage test suite
#
#   Copyright (c) 2002-2009  Dmitry Borodaenko <angdraug@debian.org>
#
#   This program is free software.
#   You can distribute/modify this program under the terms of
#   the GNU General Public License version 3 or later.
#
# vim: et sw=2 sts=2 ts=8 tw=0

ENV['SAMIZDAT_SITE'] ||= 'samizdat'
ENV['SAMIZDAT_URI'] ||= '/'

require 'test/unit'
require 'test/tc_version'
require 'test/tc_application_helper'
require 'test/tc_message_helper'
require 'test/tc_password'
