# Samizdat calendar event
#
#   Copyright (c) 2002-2009  Dmitry Borodaenko <angdraug@debian.org>
#
#   This program is free software.
#   You can distribute/modify this program under the terms of
#   the GNU General Public License version 3 or later.
#
# vim: et sw=2 sts=2 ts=8 tw=0

class EventController < Controller
  def index
    @title = _('Not Implemented')
    @content_for_layout = box(@title, '<p>' + _('Calendar is not implemented yet.') + '</p>')
  end

  private

  def create
    @member.assert_allowed_to('post')

    if @request.has_key? 'confirm'
      @request.assert_action_confirmed
      event = create_event_from_request
      event.save!
      @request.redirect(%{message/#{event.id}/describe})

    else
      @title = _('Create Event')
      @content_for_layout = box(@title, event_form)
    end
  end

  def create_event_from_request
    @request['dtstart'] or raise UserError,
      _('You must supply start date for an event')

    Event.new(site, nil) do |e|
      e.dtstart = @request['dtstart'].to_time
      e.dtend = @request['dtend'].to_time if @request['dtend']

      freq = @request['freq']
      if freq and freq != 'no'
        Recurrence.frequencies.include?(freq) or raise UserError,
          sprintf(_('Unrecognized event recurrence frequency %s'), CGI.escapeHTML(freq))

        e.rrules.push(Recurrence.new(site, nil) {|r|
          r.freq = freq
          r.until = @request['until'].to_time if @request['until']

          byhour = []
          Recurrence.hours.each do |h|
            byhour.push(h) if @request['byhour' + h.to_s]
          end
          r.byhour = byhour.join(',') unless byhour.empty?

          byday = []
          Recurrence.days.each do |d|
            byday.push(d) if @request['byday' + d]
          end
          r.byday = byday.join(',') unless byday.empty?
        })
      end
    end
  end

  def event_form
    event = Event.cached(site, @id)
    rrule = (event.rrules.first or Recurrence.new(site, nil))

    fields = [
      [:label, 'dtstart', _('Start date and time')],
        [:text, 'dtstart', event.dtstart],
      [:label, 'dtend', _('End date and time')],
        [:text, 'dtend', event.dtend],
      [:label, 'freq', _('Recurrence frequency')],
        [:select, 'freq',
          [
            ['no', _('No recurrence')],
            ['daily', _('Daily')]
          ]
        ],
      [:label, 'until', _('Repeat until date and time')],
        [:text, 'until', rrule.until],
    ]

    fields.push([:label, 'byhour', _('Repeat in specific hours')])
    Recurrence.hours.each do |h|
      h = h.to_s
      fields.push([:checkbox, 'byhour' + h], h)
    end

    fields.push([:label, 'byday', _('Repeat on specific days of week')])
    Recurrence.days.each do |d|
      fields.push([:checkbox, 'byday' + d], d)
    end

    fields.push('<br />', [:submit, 'confirm', _('Confirm')])
    secure_form(nil, *fields)
  end
end
