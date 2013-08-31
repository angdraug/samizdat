# vim: et sw=2 sts=2 ts=8 tw=0

require 'samizdat/plugins/spam'
require 'samizdat/captcha/captcha'

class ArithCaptchaPlugin < SpamPlugin
  register_as 'arith_captcha'

  def initialize(*args)
    super *args

    c = try_config(Captcha::CONFIG, {})
    @passed    = c['passed']     || 'captcha_passed'
    @saltsize  = c['saltlength'] || 4
    @usecookie = c['usecookie']
    @web_dir   = c['web_path']   || '/captcha/'
    @captcha   = Captcha.new(@site)
  end

  def add_message_fields(request)
    return '' if !@roles.include?(request.role) or
      (@usecookie and valid_cookie?(request.cookie(COOKIE_NAME)))

    ds = @captcha.random
    web_path = File.join(@web_dir, ds[:filename])

    f_entry, f_capid = FIELD_NAME
    %{<fieldset class="captcha">\n<legend>} +
    _('We need to ensure that you are human, solve the following challenge, please') +
    %{</legend>\n} +
    %{<img src="#{web_path}" alt="equation" width="#{ds[:width]}" height="#{ds[:height]}"/>\n}+
    %{<input type="text" class="required number" name="#{f_entry}" />\n} +
    %{<input type="hidden" value="#{ds[:id]}" name="#{f_capid}" />\n} +
    %{</fieldset>}
  end

  def check_message_fields(request)
    return if !@roles.include?(request.role) or request['confirm'] or
      (@usecookie and valid_cookie?(request.cookie(COOKIE_NAME)))

    f_entry, f_capid = FIELD_NAME
    their = request[f_entry].to_i
    our   = @captcha[request[f_capid]][:result].to_i

    if our == their
      request.set_cookie(COOKIE_NAME, cookie_value) if @usecookie
    else raise SpamError,
      _('Are you spam bot? If not, learn math better')
    end
  end

  private

  FIELD_NAME  = %w'a0e676 dfabb2'
  SALT_CHARS  = [(?a..?f).to_a, (?0..?9).to_a].flatten.freeze
  COOKIE_SIZE = 32
  COOKIE_NAME = 'captcha_passed'

  def salt(s = '')
    @saltsize.times { s << SALT_CHARS[ rand(SALT_CHARS.size) ] }
    s
  end

  def cookie_value(s = salt)
    (s + digest(s + @passed))[0, COOKIE_SIZE]
  end

  def valid_cookie?(cookie)
    cookie.kind_of?(String) and cookie == cookie_value(cookie[0, @saltsize])
  end
end
