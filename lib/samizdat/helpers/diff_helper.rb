# Samizdat HTML helpers for message history
#
#   Copyright (c) 2002-2009  Dmitry Borodaenko <angdraug@debian.org>
#
#   This program is free software.
#   You can distribute/modify this program under the terms of
#   the GNU General Public License version 3 or later.
#
# vim: et sw=2 sts=2 ts=8 tw=0

require 'samizdat/helpers/message_helper'

module DiffHelper
  include MessageHelper

  # calculate the table of differences
  #
  # return Array of changesets [[left, right], [same], ... ]
  #
  def calculate_diff(old, new)
    begin
      require 'algorithm/diff'
    rescue LoadError
      return [[old.join, new.join]]
    end

    table = []
    offset = 0
    i = 0
    diff = old.diff(new)   # [[op, pos, [lines]], ... ]

    while i < old.size or diff.size > 0 do
      if 0 == diff.size or
        i < diff[0][1] - ((diff[0][0] == :+)? offset : 0)   # copy

        if table[-1] and 1 == table[-1].size
          table[-1][0] << old[i]
        else
          table.push [old[i]]
        end
        i += 1
        next
      end

      if diff[0][0] == :-
        if diff[1] and diff[1][0] == :+ and diff[1][1] - offset == diff[0][1]
          # replace
          table.push [diff[0][2], diff[1][2]]
          offset += diff[1][2].size - diff[0][2].size
          i += diff[0][2].size
          diff.slice!(0, 2)
        else   # delete
          table.push [diff[0][2], []]
          offset -= diff[0][2].size
          i += diff[0][2].size
          diff.shift
        end
      else   # add
        table.push [[], diff[0][2]]
        offset += diff[0][2].size
        diff.shift
      end
    end
    table
  end

  # render difference table between two messages
  #
  def render_diff(old, new)
    old, new = [old, new].collect do |message|
      info = Resource.new(@request, message.id).list_item
      info = hide_message(info, message.hidden?)

      content = message.content
      if content.inline?
        format = content.format
        format = 'text/plain' if 'application/x-squish' == format

        body = content.body
        body =
          case format
          when nil
            body.split(/(?=\n\n)/)
          when 'text/plain', 'text/textile'
            body.split(/(?=\n)/)
          when 'text/html'
            body.split(%r{(?=<(?!\s*/))})
          else
            [body]
          end
        body = body.collect {|line| content.render(@request, :full, line) }
      else
        body = [ content.render(@request, :short) ]
      end

      {
        :info => info,
        :body => body,
        :hidden => message.hidden?
      }
    end

    %{<table class="diff">\n<thead><tr>\n} +
    [old, new].collect {|version| "<th>#{version[:info]}</th>\n" }.join +
    %{</tr></thead>\n<tbody>\n} +
    calculate_diff(old[:body], new[:body]).collect {|left, right|
      width = right ? ' style="width: 50%"' : ' colspan="2"'

      left = left.join if left.kind_of? Array
      right = right.join if right.kind_of? Array

      left and left = {
        :hidden => old[:hidden],
        :body => left,
        :class => (right ? ' class="delete"' : '')
      }
      right and right = {
        :hidden => new[:hidden],
        :body => right,
        :class => ' class="add"'
      }

      %{<tr>\n} + [left, right].compact.collect {|line|
        (line[:body].size > 0) ?
          %{<td#{width}#{line[:class]}><div class="content">#{hide_message(line[:body], line[:hidden])}</div></td>\n} :
          %{<td#{width}><div class="content">&nbsp</div></td>\n}
      }.join + "</tr>\n"
    }.join + %{</tbody></table>\n}
  end
end
