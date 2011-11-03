# Samizdat password encryption
#
#   Copyright (c) 2002-2011  Dmitry Borodaenko <angdraug@debian.org>
#
#   This program is free software.
#   You can distribute/modify this program under the terms of
#   the GNU General Public License version 3 or later.
#
# vim: et sw=2 sts=2 ts=8 tw=0

class Password
  ALNUM = '0123456789' +
          'ABCDEFGHIJKLMNOPQRSTUVWXYZ' +
          'abcdefghijklmnopqrstuvwxyz'

  SALT_SIZE = 8
  TYPE = '1'

  DIGEST_CLASSES = {
    '1' => Digest::SHA512
  }

  # generate salted encrypted password using the default digest
  #
  def Password.encrypt(password)
    salt = ''
    size = ALNUM.size
    SALT_SIZE.times { salt << ALNUM[ rand(size) ] }
    '$' + TYPE + '$' + salt + '$' +
      DIGEST_CLASSES[TYPE].hexdigest(salt + password)
  end

  def Password.check(password, encrypted_password)
    nothing, type, salt, hash = encrypted_password.split('$')
    if type and salt and hash
      digest_class = DIGEST_CLASSES[type] or raise RuntimeError,
        "Unrecognized password digest type: #{type}"
      digest_class.hexdigest(salt + password) == hash
    else
      digest(password) == encrypted_password
    end
  end

  # generate random password
  #
  def Password.random
    p = ''; 1.upto(10) { p << (97 + rand(26)).chr }   # 97 == ?a
    p
  end
end
