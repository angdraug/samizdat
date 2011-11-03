# Samizdat engine exceptions
#
#   Copyright (c) 2002-2011  Dmitry Borodaenko <angdraug@debian.org>
#
#   This program is free software.
#   You can distribute/modify this program under the terms of
#   the GNU General Public License version 3 or later.
#
# vim: et sw=2 sts=2 ts=8 tw=0

require 'samizdat'

# raised when non-existent resource is requested
class ResourceNotFoundError < RuntimeError; end

# raised if a request can't be attributed to any of the configured sites
class SiteNotFoundError < ResourceNotFoundError; end

# raised on incorrect user action
class UserError < RuntimeError; end

# raised when format of a file upload is not supported
class UnknownFormatError < UserError; end

# raised on action that requires login
class AuthError < UserError; end

# raised when account is blocked for email confirmation
class AccountBlockedError < UserError; end

# raised on attempt to re-raise same moderation request
class ModerationRequestExistsError < UserError; end
