# Samizdat HTML helpers for calendar events
#
#   Copyright (c) 2002-2009  Dmitry Borodaenko <angdraug@debian.org>
#
#   This program is free software.
#   You can distribute/modify this program under the terms of
#   the GNU General Public License version 3 or later.
#
# vim: et sw=2 sts=2 ts=8 tw=0

require 'samizdat/helpers/application_helper'

module EventHelper
  include ApplicationHelper

  def describe_event(event)
    text = format_date(event.dtstart)
    text << ' - ' + format_date(event.dtend) if event.dtend
    text << ', ' + _('recurrent') unless event.rrules.empty?
    text
  end

  def describe_freq(rrule)
    i = rrule.interval
    {
      'secondly' => sprintf(n_('every second', 'every %s seconds', i), i),
      'minutely' => sprintf(n_('every minute', 'every %s minutes', i), i),
      'hourly' => sprintf(n_('every hour', 'every %s hours', i), i),
      'daily' => sprintf(n_('every day', 'every %s days', i), i),
      'weekly' => sprintf(n_('every week', 'every %s weeks', i), i),
      'monthly' => sprintf(n_('every month', 'every %s months', i), i),
      'yearly' => sprintf(n_('every year', 'every %s years', i), i)
    }[rrule.freq]
  end

  # Detect and collapse stretches in a sorted list of integers. When
  # block is given, list items are passed through the block before being
  # included in the final result.
  #
  def display_as_stretches(list)
    stretches = [[ list[0] ]]

    1.upto(list.size - 1) do |i|
      if list[i] == stretches[-1][-1] + 1
        stretches[-1][1] = list[i]
      else
        stretches.push([list[i]])
      end
    end

    if block_given?
      stretches.collect! {|stretch|
        stretch.collect {|item| yield item }
      }
    end

    stretches.collect {|stretch|
      stretch.join(' - ')
    }.join(', ')
  end

  def describe_byday(rrule)
    if rrule.byday
      h = {
        'MO' => _('Monday'),
        'TU' => _('Tuesday'),
        'WE' => _('Wednesday'),
        'TH' => _('Thursday'),
        'FR' => _('Friday'),
        'SA' => _('Saturday'),
        'SU' => _('Sunday')
      }

      days = rrule.byday.split(',').collect {|dd|
        Recurrence.days.find_index(dd)
      }.sort

      _('on ') + display_as_stretches(days) {|day|
        h[ Recurrence.days[day] ]
      }
    end
  end

  def describe_byhour(rrule)
    if rrule.byhour
      hours = rrule.byhour.split(',').collect {|h| h.to_i }.sort
      sprintf(_('at %s hours'), display_as_stretches(hours))
    end
  end

  def describe_recurrence(rrule)
    [ describe_freq(rrule), describe_byday(rrule), describe_byhour(rrule) ].compact.join('; ')
  end
end
