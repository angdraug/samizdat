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

  # list supplied tags in a straight line
  #
  def tag_line(id, tags)
    return nil if tags.empty?

    %{<a href="#{id}#tags">}+_('related to')+'</a>: ' +
    tags.sort_by {|t| -t.sort_index }.collect {|tag|
      resource_href(tag.id, tag.name(@request))
    }.join(', ')
  end

  # render _message_ info line (except tags)
  #
  def message_info(message, mode)
    creator = member_link(message.creator)
    date = format_date(message.date)

    if :full == mode
      parent = 
        case message.part_of_property
        when 's::inReplyTo', 'dct::isPartOf'
          %{<a href="#{message.part_of}">} + _('parent message') + '</a>'
        when 's::isTranslationOf'
          %{<a href="#{message.translation_of}">} + _('the original') + '</a>'
        when 'dct::isVersionOf'
          %{<a href="#{message.version_of}">} + _('current version') + '</a>'
        when 's::subTagOf'
          %{<a href="#{message.sub_tag_of}">} + _('parent tag') + '</a>'
        end
      if message.previous_part
        previous_part = %{<a href="#{message.previous_part}">} + _('previous part') + '</a>'
      end
      if message.next_part
        next_part = %{<a href="#{message.next_part}">} + _('next part') + '</a>'
      end
      if message.id and message.nversions.to_i > 0
        history = %{<a href="history/#{message.id}">} + _('history') + '</a>'
      end
      if message.id and format = InlineFormat.instance[message.content.format]
        source = %{<a href="message/#{message.id}/source" title="} +
          _('view source') + %{">#{format}</a>}
      end
    end

    replies = %{<a href="#{message.id}#replies">} + _('replies') +
      '</a>:&nbsp;' + message.nreplies_all.to_s if message.nreplies.to_i > 0

    if message.translations.to_a.size > 0
      language = _('language') + ': ' + message.lang if message.lang
      translations = _('translation') + ': ' +
        message.translations.sort_by {|t| t[:lang] }.collect {|t|
          %{<a href="#{t[:msg]}">#{t[:lang]}</a>}
        }.join(' ')
    end

    tags = tag_line(message.id, message.tags)

    hidden = _('hidden') if message.hidden?

    moderation_log = %{<a href="moderation/#{message.id}">} + _('moderation log') + '</a>' if
      message.id.kind_of?(Integer) and
      Moderation.find(site, message.id, { :message => true }).size > 0

    link = %{<a href="#{message.id}">} + _('link') + '</a>' if :short == mode and message.part_of

    [ sprintf(_('by&nbsp;%s on&nbsp;%s'), creator, date.to_s),
      hidden, moderation_log, parent, previous_part, next_part, history,
      source, replies, language, translations, tags, link
    ].compact.join(",\n ")
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
    buttons = ''

    unless message.version_of
      # all of these buttons only work with the current version

      if @member.allowed_to?('post')
        message.may_reply? and
          buttons << message_button(message.id, 'reply', _('Reply'))

        message.translation_of.nil? and config['locale']['languages'].size > 1 and
          buttons << message_button(message.id, 'translate', _('Translate'))

        may_edit =
          if @session.member.nil?   # guest
            false
          elsif message.creator.id == @session.member   # creator
            true
          else   # everyone else
            message.open
          end
        may_edit and
          buttons << message_button(message.id, 'edit', _('Edit'))
      end

      if @request.moderate?
        buttons <<
          (message.hidden? ?
            message_button(message.id, 'unhide', _('UNHIDE'), :moderator_action) :
            message_button(message.id, 'hide', _('HIDE'), :moderator_action)) <<
          (message.locked? ?
            message_button(message.id, 'unlock', _('UNLOCK'), :moderator_action) :
            message_button(message.id, 'lock', _('LOCK'), :moderator_action)) <<
          message_button(message.id, 'reparent', _('REPARENT'), :moderator_action) <<
          message_button(message.id, 'takeover', _('TAKE OVER'), :moderator_action)
      end
    end

    request_status = Moderation.request_status(site, message.id)

    if @request.moderate?
      # old versions can still be replaced
      buttons << message_button(message.id, 'replace', _('REPLACE'), :moderator_action)

      if :requested == request_status
        buttons << message_button(message.id, 'acknowledge', _('ACKNOWLEDGE'), :moderator_action)
      end

    elsif @member.allowed_to?('post') and :none == request_status
      # moderation can be requested for any message version
      buttons << message_button(message.id, 'request_moderation', _('Request Moderation'))
    end

    ('' == buttons) ? '' : %{<div class="foot">#{buttons}</div>\n}
  end

  # render full message
  #
  # _message_ is an instance of Message class
  #
  # _mode_ can be :short or :full
  #
  def message(message, mode)
    info = message_info(message, mode)

    translation = (:full == mode) ?
      message :
      message.select_translation(@request.accept_language)

    if :short == mode and   # title is already in the page head in :full mode
      not (message.part_of and
           Message.cached(site, message.part_of).content.title == message.content.title)

      title = translation.content.title
      title = Tag.tag_title(title) if message.nrelated > 0
      title = Rack::Utils.escape_html(limit_string(title))
      title = %{<div class="title">#{resource_href(message.id, title)}</div>\n}
    end

    content = message_content(translation, mode).to_s

%{<div class="message" id="id#{message.id}">
#{title}<div class="info">#{info}</div>
<div class="content">#{ hide_message(content, message.hidden?) }</div>
</div>\n}
  end

  # wrap message in a hidden-message div if it is hidden
  #
  def hide_message(message, hidden=false)
    if hidden
      message.gsub!(/<(a|img)\s+([^>]+?\s+?)?(href|src)([^>]*)>/i,
        '<\1 \2title\4>')   # cripple URLs and images
      %{<div class="hidden-message">\n#{message}</div>\n}
    else
      message
    end
  end
end
