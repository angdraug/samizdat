# Samizdat member registration and preferences
#
#   Copyright (c) 2002-2011  Dmitry Borodaenko <angdraug@debian.org>
#
#   This program is free software.
#   You can distribute/modify this program under the terms of
#   the GNU General Public License version 3 or later.
#
# vim: et sw=2 sts=2 ts=8 tw=0

class MemberController < Controller

  # view member profile
  #
  def index
    @request.redirect('member/settings')
  end

  def settings

    @title = _('Interface Settings')
    @content_for_layout = render_template('member_settings.rhtml', binding)
  end

  # store UI options in cookies
  #
  def set
    %w[lang style nostatic ui monolanguage].each do |param|
      value, = @request.values_at([param])
      if value
        @request.set_cookie(param, value, forever)
        @request.redirect
      end
    end

    moderate, = @request.values_at %w[moderate]
    if moderate   # cookie with timeout
      @request.set_cookie('moderate', moderate, config['timeout']['moderate'])
      @request.redirect
    end
  end

  def profile
    assert_member
    @title = _('Profile')
    @content_for_layout = render_template('member_profile.rhtml', binding)
  end

  def account
    assert_member
    @title = _('Account')
    @email = rdf.get_property(@session.member, 's::email') if @session.member
    @content_for_layout = render_template('member_account.rhtml', binding)
  end

  def create
    @title = _('Create New Account')
    @email = rdf.get_property(@session.member, 's::email') if @session.member
    @content_for_layout = render_template('member_create.rhtml', binding)
  end

  def change_profile
    record_changes('member/profile') do
      member = Member.cached(site, @session.member)

      notices = [change_full_name] + site.plugins['profile'].collect {|plugin|
        plugin.update(member, @request)
      }.flatten
      notices.compact!

      member.preferences.save
      cache.flush unless notices.empty?

      notices
    end
  end

  # change existing account
  #
  def change_account
    record_changes('member/account') do
      [ change_password, change_email ]
    end
  end

  # create new account
  #
  def create_account
    check_params

    db.transaction do
      check_duplicates

      (@login and @email and @password) or raise UserError,
        _("You didn't fill all mandatory fields")

      # create account
      p = Password.encrypt(@password)
      db[:member].insert(
        :login => @login,
        :email => @email,
        :password => (site.email_enabled? ? nil : p)
      )

      if site.email_enabled?   # request confirmation over email
        confirm = confirm_hash(@login)

        prefs = Preferences.new(site, @login)
        prefs['email'] = @email
        prefs['password'] = p
        prefs.save(confirm)

        request_confirmation(
          @email, confirm,
          _('Your email address was used to create an account.'))
      end
    end

    start_session_for_new_account(@login, @password)
  end

  def login
    login, password = @request.values_at %w[login password]

    if login and password
      if cookie = @session.start!(login, password)
        set_session_cookie(cookie)
        @request.redirect_when_done
      else
        @title = _('Login Failed')
      end

    else
      @request.set_redirect_when_done_cookie
      @title = _('Log in')
    end
    @content_for_layout = render_template('member_login.rhtml', binding)
  end

  def logout
    if @session.member
      @session.clear!
      @request.unset_cookie('session')
    end
    @request.redirect
  end

  # check in confirmed email and enable the account
  #
  def confirm
    confirm, = @request.values_at %w[hash]

    start_session = false   # scope fix
    login = nil

    db.transaction do
      login = db[:member].filter(:confirm => confirm).get(:login)

      login.nil? and raise UserError, _('Confirmation hash not found')
      @session.member and @session.login != login and raise UserError,
        _('This confirmation hash is intended for another user')

      # set password and email from preferences
      prefs = Preferences.new(site, login)
      ds = db[:member].filter(:login => login)
      password = prefs['password'] and ds.update(:password => password)
      email = prefs['email'] and ds.update(:email => email)
      prefs.delete('password')
      prefs.delete('email')
      prefs.save

      # clear confirmation hash
      ds.update(:confirm => nil)

      start_session = true if password and email and not @session.member
    end

    if start_session
      @request.add_notice('<p>' + _('Account unblocked.') + '</p>')
      start_session_for_new_account(login)
    else
      @title = _('Confirmation Accepted')
      @content_for_layout = render_template('member_confirm.rhtml', binding)
    end
  end

  # Recover inaccessible accounts.
  #
  # Use cases:
  # - forgotten password (active account)
  # - confirmation email lost for new account (blocked, prefs holds new
  #   password and email)
  # - confirmation email lost for change email (active account, prefs holds new
  #   email)
  # - account blocked by moderators (blocked, prefs holds old password)
  #
  def recover
    site.email_enabled? or raise UserError,
      _("Sorry, password recovery not enabled on this site")
    @session.member.nil? or raise UserError,
      _('You are already logged in')

    login, = @request.values_at %w[login]

    good_login = (login and login =~ LOGIN_PATTERN)

    if good_login
      p = Password.random
      db.transaction do
        email = db[:member].filter(:login => login).get(:email)
        email or raise UserError, _('Wrong login')
        confirm = confirm_hash(login)

        prefs = Preferences.new(site, login)
        prefs['password'] = Password.encrypt(p)
        prefs.delete('email')  # cancel changing email while recovering password
        prefs.save(confirm)

        request_confirmation(email, confirm,
          sprintf(_('New password was generated for your account: %s'), p))
      end # transaction
    end

    @title = _('Recover Lost Password')
    @content_for_layout = render_template('member_recover.rhtml', binding)
  end

  def block
    moderate('block') do |login, password, prefs|
      password.nil? and raise UserError, _('Account is already blocked')
      Member.cached(site, @id).allowed_to?('moderate') and
        raise UserError, _('Moderator accounts can not be blocked')

      prefs['blocked_by'] = @session.member
      prefs['password'] = password   # remember password
      prefs.save
      db[:member][:id => @id] = {:password => nil, :session => nil}
    end
  end

  def unblock
    moderate('unblock') do |login, password, prefs|
      password.nil? or raise UserError, _('Account is not blocked')
      prefs['password'] or raise UserError, _("Can't unblock, the account has no password")

      ds = db[:member].filter(:id => @id)

      if site.email_enabled? and prefs['email']
        email = prefs.delete('email')   # confirm email
        ds.update(:email => email)
      end

      password = prefs.delete('password')   # restore password
      ds.update(:password => password)

      prefs.delete('blocked_by')
      prefs.save
    end
  end

  private

  def assert_member
    @session.member or raise UserError,
      _('You need to <a href="member/login">login</a> to modify your profile or account parameters')
  end

  def secure_action(action)
    if (not @request.ssl?) and
      config['https'] and config['https']['force_secure_session']

      config['https']['base'] + action

    else
      action
    end
  end

  def password_recovery_link
    site.email_enabled? ?
      '<p><a href="member/recover">'+_('Recover Lost Password')+'</a></p>' : ''
  end

  def record_changes(route)
    check_params
    @request.assert_action_confirmed

    changes = []   # scope fix
    db.transaction do
      check_duplicates
      changes = yield.compact
    end

    if not changes.empty?
      @request.add_notice(
        changes.collect {|line|
          '<p>' + line + '</p>'
        }.join)
    end
    @request.redirect(route)
  end

  def change_full_name
    if @full_name and @full_name != @session.full_name
      db[:member][:id => @session.member] = {:full_name => @full_name}
      return sprintf(_('%s updated'), _('Full name'))
    end
  end

  def change_password
    if @password
      ds = db[:member].filter(:id => @session.member)
      p = ds.get(:password)
      Password.check(@request['password'], p) or raise AuthError,
        _('Wrong current password')
      Password.check(@password, p) and return nil   # unchanged

      ds.update(:password => Password.encrypt(@password))
      return sprintf(_('%s updated'), _('Password'))
    end
  end

  def change_email
    if @email and @email != @current_email
      if site.email_enabled?   # with confirmation
        confirm = confirm_hash(@session.login)

        prefs = Preferences.new(site, @session.login)
        prefs['email'] = @email
        prefs.delete('password')   # don't change password
        prefs.save(confirm)

        request_confirmation(@email, confirm,
          _('Your email address was given for an account.'))

        return _('Confirmation request is sent to your new email address.')

      else   # without confirmation
        db[:member][:id => @session.member] = {:email => @email}
        return sprintf(_('%s updated'), _('Email'))
      end
    end
  end

  def moderate(action)
    assert_moderate
    Model.validate_id(@id) or raise ResourceNotFoundError, @id.to_s

    if @request.has_key? 'confirm'
      @request.assert_action_confirmed
      db.transaction do
        m = db[:member].filter(:id => @id).select(:login, :password).first
        m.nil? and raise ResourceNotFoundError, @id.to_s

        yield m[:login], m[:password], Preferences.new(site, m[:login])
        log_moderation(action)
      end
      cache.flush
      @request.redirect(@id)
    else
      @title = _('Change Account Status')
      @content_for_layout = render_template('member_moderate.rhtml', binding)
    end
  end

  LOGIN_PATTERN = Regexp.new(/\A[a-zA-Z0-9]+\z/).freeze
  EMAIL_PATTERN = Regexp.new(/\A[[:alnum:]._-]+@[[:alnum:].-]+\z/).freeze

  # validate and store account parameters
  #
  def check_params
    @login, @full_name, @email, @password, password2 = \
      @request.values_at %w[login full_name email password1 password2]

    # validate password
    @password == password2 or raise UserError,
      _('Passwords do not match')

    # validate login
    if @login and @session.member.nil?
      @login == 'guest' and raise UserError,
        _('Login name you specified is reserved')
      (@login =~ LOGIN_PATTERN and @login.downcase == @login) or raise UserError,
        _('Use only latin letters and numbers in login name')
    end

    # validate email
    @email.nil? or @email =~ EMAIL_PATTERN or raise UserError,
      sprintf(_("Malformed email address: '%s'"), Rack::Utils.escape_html(@email))

    site.plugins.find_all('spam', :check_email) do |plugin|
      plugin.check_email(@email)
    end
  end

  # check full_name and email for duplicates
  #
  # run it from inside the same transaction that stores the verified values
  #
  def check_duplicates
    ds = db[:member]
    if @session.member
      @current_email = rdf.get_property(@session.member, 's::email')
      ds = ds.filter(:id => @session.member).invert
    end

    if @full_name and @full_name != @session.full_name
      m = ds.filter(:full_name => @full_name).first
      m.nil? or raise UserError,
        _('Full name you have specified is used by someone else')
    end
    if @email and @email != @current_email
      m = ds.filter(:email => @email).first
      m.nil? or raise UserError,
        _('Email address you have specified is used by someone else')
    end
    if @login and @session.member.nil?
      m = ds.filter(:login => @login).first
      m.nil? or raise UserError,
        _('Login name you specified is already used by someone else')
    end
  end

  # wrapper around sendmail
  #
  def send_mail(to, subject, body)
    if EMAIL_PATTERN =~ to
      to.untaint
    else
      raise UserError, sprintf(_("Malformed email address: '%s'"), Rack::Utils.escape_html(email))
    end
    message_id = config['email']['address'].sub(/^[^@]*/,
      Time.now.strftime("%Y%m%d%H%M%S." + Process.pid.to_s))
    IO.popen(config['email']['sendmail']+' '+to, 'w') do |io|
      io.write(
%{From: Samizdat <#{config['email']['address']}>
To: #{to}
Subject: #{subject}
Message-Id: <#{message_id}>

} + body)
    end
    0 == $? or raise RuntimeError, _('Failed to send email')
  end

  # generate confirmation hash
  #
  def confirm_hash(login)
    digest(login + Time.now.to_s + rand.to_s)
  end

  # send confirmation request
  #
  def request_confirmation(email, hash, action)
    send_mail(
      email, 'CONFIRM ' + hash,
      _('Site') + ': ' + @request.base + "\n\n" +
      action + "\n\n" +
      _('To confirm this action, visit the following web page:') + "\n\n" +
      @request.base + 'member/confirm?hash=' + hash + "\n\n" +
      _('To cancel this action, ignore this message.'))
  end

  def set_session_cookie(cookie)
    @request.set_cookie('session', cookie, config['timeout']['last'])
  end

  def start_session_for_new_account(login, password = nil)
    if cookie = @session.start!(login, password)
      set_session_cookie(cookie)
      @request.unset_cookie('redirect_when_done')
      @request.redirect('member/profile')
    else
      raise RuntimeError,
        'Login error: failed to start session for new account: ' + login.inspect
    end
  end
end
