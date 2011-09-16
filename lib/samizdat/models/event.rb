# Samizdat event model
#
#   Copyright (c) 2002-2009  Dmitry Borodaenko <angdraug@debian.org>
#
#   This program is free software.
#   You can distribute/modify this program under the terms of
#   the GNU General Public License version 3 or later.
#
# vim: et sw=2 sts=2 ts=8 tw=0

require 'samizdat'
#require 'texp'

# Associated with a text/calendar resource (RFC 2445).
#
class Event < Model
  def initialize(site, id)
    super

    if @id
      @dtstart, @dtend, @description = rdf.select_one(
        %q{SELECT ?dtstart, ?dtend, ?desc
        WHERE (ical::dtstart :event ?dtstart)
        OPTIONAL (ical::dtend :event ?dtend)
                 (dc::description :event ?desc)},
        :event => @id
      )

      @rrules = rdf.select_all(
        %q{SELECT ?rrule, ?freq, ?interval, ?until, ?byday, ?byhour
        WHERE (s::rruleEvent ?rrule :event)
              (ical::freq ?rrule ?freq)
              (ical::interval ?rrule ?interval)
        OPTIONAL (ical::until ?rrule ?until FILTER ?until IS NULL OR ?until > :now)
                 (ical::byhour ?rrule ?byhour)
                 (ical::byday ?rrule ?byday)},
        nil, nil,
        :event => @id, :now => Time.now
      ).collect {|rrule, freq, interval, until_, byday, byhour|
        Recurrence.new(rrule) {|r|
          r.event = @id
          r.freq = freq
          r.interval = interval
          r.until = until_
          r.byday = byday
          r.byhour = byhour
        }
      }

    else
      @rrules = []
    end
  end

  attr_reader :id
  attr_accessor :description, :dtstart, :dtend, :rrules

  def expired?
    now = Time.now
    @dtstart < now and (@dtend.nil? or @dtend < now) and @rrules.empty?
  end

  def save!
    @dtstart or raise RuntimeError,
      'Start date must be specified for an event'

    db.transaction do
      @id ? update! : insert!
    end
  end

  def Event.find_current(dtstart = Time.now, dtend = Time.now)
    rdf.select_all(
      %q{SELECT ?event
      WHERE (ical::dtstart ?event ?dtstart FILTER ?dtstart <= :dtend)
            (ical::dtend ?event ?dtend)
      OPTIONAL (s::rruleEvent ?rrule ?event)
               (ical::until ?rrule ?until FILTER ?until IS NULL OR ?until > :dtstart)
      LITERAL ?dtend > :now OR ?rrule IS NOT NULL
      ORDER BY ?event},
      :dtstart => dtstart, :dtend => dtstart
    ).collect {|event,| Event.new(event) }.find_all {|event|
      event.match(dtstart, dtend)
    }
  end

  def match(dtstart, dtend)
    return false if @dtstart > dtend

    return true if @dtend > dtstart

    @rrules.each do |rrule|
      return true if rrule.match(dtstart, dtend)
    end
  end

  private

  def insert!
    @id, = rdf.assert(
      %{INSERT ?event
      WHERE (ical::dtstart ?event :dtstart)
            (ical::dtend ?event :dtend)},
      :dtstart => @dtstart, :dtend => @dtend
    )

    @rrules.each do |r|
      r.event = @id
      r.save!
    end
  end

  def update!
    rdf.assert(
      %{UPDATE ?desc = :desc, ?dtstart = :dtstart, ?dtend = :dtend
      WHERE (dc::description :event ?desc)
            (ical::dtstart :event ?dtstart)
            (ical::dtend :event ?dtend)},
      :event => @id, :desc => @description,
      :dtstart => @dtstart, :dtend => @dtend
    )

    @rrules.each {|r| r.save! }
  end
end

class Recurrence < Model
  def Recurrence.frequencies
    %w[secondly minutely hourly daily weekly monthly yearly]
  end

  def Recurrence.days
    %w[MO TU WE TH FR SA SU]
  end

  def Recurrence.hours
    0..23
  end

  def initialize(site, id)
    super
    @interval ||= 1
  end

  attr_reader :id
  attr_accessor :event, :freq, :interval, :until, :byhour, :byday

  def match(dtstart, dtend)
    # fixme: TExp needs to be considerably expanded to cover all of RFC 2445
    texp do
      te = [ every(@interval, FREQ_PERIOD[@freq], @event.dtstart.to_date) ]
      te.push(dow(*@byday.split(','))) if @byday
      #te = TExp::And.new(*te)
      te.includes?(dtstart) or te.includes?(dtend)
    end
  end

  # Run from inside transaction.
  #
  def save!
    @event or raise RuntimeError,
      'Recurrence rule must be associated with an event'
    (@freq and @interval) or raise RuntimeError,
      'Recurrence rule must include frequency and interval'

    @id ? update! : insert!
  end

  private

  FREQ_PERIOD = {
    'secondly' => 'second',
    'minutely' => 'minute',
    'hourly' => 'hour',
    'daily' => 'day',
    'weekly' => 'week',
    'monthly' => 'month',
    'yearly' => 'year'
  }

  def insert!
    rdf.assert(
      %{INSERT ?rrule
      WHERE (s::rruleEvent ?rrule :event)
            (ical::freq ?rrule :freq)
            (ical::interval ?rrule :interval)
            (ical::until ?rrule :until)
            (ical::byhour ?rrule :byhour)
            (ical::byday ?rrule :byday)},
      :event => @event, :freq => @freq, :interval => @interval,
      :until => @until, :byhour => @byhour, :byday => @byday
    )
  end

  def update!
    rdf.assert(
      %{UPDATE
      WHERE (s::rruleEvent :rrule :event)
            (ical::freq :rrule :freq)
            (ical::interval :rrule :interval)
            (ical::until :rrule :until)
            (ical::byhour :rrule :byhour)
            (ical::byday :rrule :byday)},
      :rrule => @id, :event => @event, :freq => @freq, :interval => @interval,
      :until => @until, :byhour => @byhour, :byday => @byday
    )
  end
end
