# Samizdat moderation
#
#   Copyright (c) 2002-2011  Dmitry Borodaenko <angdraug@debian.org>
#
#   This program is free software.
#   You can distribute/modify this program under the terms of
#   the GNU General Public License version 3 or later.
#
# vim: et sw=2 sts=2 ts=8 tw=0

require 'samizdat'

class Moderation
  include SiteHelper

  ACTION_LABELS = {
    'hide' => 'HIDE',
    'unhide' => 'UNHIDE',
    'lock' => 'LOCK',
    'unlock' => 'UNLOCK',
    'reparent' => 'REPARENT',
    'takeover' => 'TAKE OVER',
    'replace' => 'REPLACE',
    'block' => 'BLOCK',
    'unblock' => 'UNBLOCK',
    'request' => 'Request Moderation',
    'acknowledge' => 'ACKNOWLEDGE'
  }

  def initialize(site, resource, action, moderator = nil, date = Time.now)
    @site = site

    @resource = Model.validate_id(resource)
    @resource or raise RuntimeError, "Invalid moderation resource id"

    @action = validate_action(action)

    @moderator = moderator
    @date = date
  end

  attr_reader :resource, :action, :moderator, :date

  # log moderatorial action (the method assumes that you check permissions
  # first and invoke it from inside transaction)
  #
  def log!
    db.do 'INSERT INTO Moderation (moderator, action, resource)
      VALUES (?, ?, ?)', @moderator, @action, @resource
        @date = Time.now
  end

  # produce a list of moderation actions for the given resource (or all
  # resources when nil), most recent first
  #
  # options:
  # * :message - resource is a message, include moderation actions for parts
  #
  def Moderation.find(site, resource = nil, options = {})
    return [] unless resource.nil? or resource.kind_of? Integer   # e.g. upload

    query = %{
      SELECT l.action_date, l.moderator, l.action, l.resource FROM moderation AS l}

    if resource.kind_of? Integer
      if options[:message]
        query << %{
          LEFT JOIN Part AS p
            ON p.id = l.resource
          WHERE (l.resource = #{resource}
            OR p.part_of = #{resource})}

      else
        query << %{
          WHERE l.resource = #{resource}}
      end

    else
      # in general moderation log, don't show moderation requests
      query << %{
        WHERE l.moderator IS NOT NULL}
    end

    # ignore legacy moderation actions
    known_actions = "'" << ACTION_LABELS.keys.join("', '") << "'"

    query << %{
        AND l.action IN (#{known_actions})
      ORDER BY l.action_date DESC}

    SqlDataSet.new(site, query)
  end

  # produce list of pending moderation requests, oldest first
  #
  def Moderation.find_pending(site)
    SqlDataSet.new(site, %{
      SELECT requested.action_date, requested.resource
      FROM Moderation AS requested
      INNER JOIN Resource AS r
        ON requested.resource = r.id
      LEFT JOIN Moderation AS acknowledged
        ON acknowledged.resource = requested.resource
          AND acknowledged.moderator IS NOT NULL
          AND acknowledged.action_date >= r.published_date
      WHERE requested.action = 'request'
        AND acknowledged.action_date IS NULL
      ORDER BY requested.action_date DESC})
  end

  # returns :acknowledged if request has already been raised and acknowledged,
  # :requested if it's already been requested but hasn't been actioned, and
  # :none otherwise
  #
  def Moderation.request_status(site, resource)
    site.cache.fetch_or_add("moderation/request_status/#{resource.to_i}") do
      requested_date, acknowledged_date = site.db.select_one %q{
        SELECT
          requested.action_date AS requested_date,
          acknowledged.action_date AS acknowledged_date
        FROM Moderation AS requested
        INNER JOIN Resource AS r
          ON requested.resource = r.id
        LEFT JOIN Moderation AS acknowledged
          ON acknowledged.resource = requested.resource
            AND acknowledged.moderator IS NOT NULL
            AND acknowledged.action_date >= r.published_date
        WHERE requested.resource = ?
          AND requested.action = 'request'}, resource.to_i

      if acknowledged_date
        :acknowledged
      elsif requested_date
        :requested
      else
        :none
      end
    end
  end

  # raises ModerationRequestExistsError if moderation request can't be raised
  #
  def Moderation.check_request(site, resource)
    case Moderation.request_status(site, resource)
    when :acknowledged
      raise ModerationRequestExistsError,
        _('This resource has already been moderated since it was last modified')

    when :requested
      raise ModerationRequestExistsError,
        _('Moderation of this resource has already been requested')
    end
  end

  # notify moderator that a resource requires moderation
  #
  # raises ModerationRequestExistsError if moderation is already pending or was
  # acknowledged since resource was last modified
  #
  def Moderation.request!(site, resource)
    site.db.transaction do |db|
      moderation = Moderation.new(site, resource, 'request')
      Moderation.check_request(site, resource)
      moderation.log!
    end
  end

  private

  def validate_action(action)
    ACTION_LABELS[action] or raise RuntimeError,
      'Unknown moderation action: ' << action.inspect
    action
  end
end
