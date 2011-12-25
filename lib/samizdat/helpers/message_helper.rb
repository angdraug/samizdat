# Samizdat HTML helpers for messages
#
#   Copyright (c) 2002-2011  Dmitry Borodaenko <angdraug@debian.org>
#
#   This program is free software.
#   You can distribute/modify this program under the terms of
#   the GNU General Public License version 3 or later.
#
# vim: et sw=2 sts=2 ts=8 tw=0

require 'samizdat/helpers/application_helper'

module MessageHelper
  include ApplicationHelper

  # render link to full message
  #
  def full_message_href(id)
    %{<p><a href="#{id}">}+_('See the full message')+'</a></p>'
  end

  # inline formats that need a link to view source
  #
  SOURCE_FORMAT = {
    'text/textile' => 'textile',
    'text/html' => 'html'
  }

  # render _message_ info line (except tags)
  #
  def message_info(message, mode)
    format = SOURCE_FORMAT[message.content.format] if message.id

    moderation_log = (message.id.kind_of?(Integer) and
      Moderation.find(site, message.id, { :message => true }).size > 0)

    render_template('messagehelper_message_info.rhtml', binding)
  end

  # render _message_ content, _mode_ can be :short or :full
  #
  def message_content(message, mode)
    return '' if :list == mode

    content = message.content

    if content.cacheable? and :short == mode
      short = content.render(@request, :short)
      if short != content.render(@request, :full)
        short += full_message_href(message.id)
      end
      short

    else
      content.render(@request, mode)
    end
  end

  def message_button(id, action, label, css=:action)
    %{<a class="#{css}" href="message/#{id}/#{action}">#{label}</a>\n}
  end

  # render buttons for _message_ in :page mode
  #
  def message_buttons(message)
      if @member.allowed_to?('post')
        may_edit =
          if @session.member.nil?   # guest
            false
          elsif message.creator.id == @session.member   # creator
            true
          else   # everyone else
            message.open
          end
      end

    request_status = Moderation.request_status(site, message.id)

    render_template('messagehelper_message_buttons.rhtml', binding)
  end

  # render full message
  #
  # _message_ is an instance of Message class
  #
  # _mode_ can be :short or :full
  #
  def message(message, mode)
    translation = (:full == mode) ?
      message :
      message.select_translation(@request.accept_language)

    if :short == mode and   # title is already in the page head in :full mode
      not (message.part_of and
           Message.cached(site, message.part_of).content.title == message.content.title)

      title = translation.content.title
      title = Tag.tag_title(title) if message.nrelated > 0
      title = Rack::Utils.escape_html(limit_string(title))
    end

    content = message_content(translation, mode).to_s

    render_template('messagehelper_message.rhtml', binding)
  end

  # wrap message in a hidden-message div if it is hidden
  #
  def hide_message(message, hidden=false)
    render_template('messagehelper_hide_message.rhtml', binding)
  end
end
