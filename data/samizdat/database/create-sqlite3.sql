-- Samizdat Database Creation - SQLite3 (Experimental)
--
--   Copyright (c) 2002-2011  Dmitry Borodaenko <angdraug@debian.org>
--
--   This program is free software.
--   You can distribute/modify this program under the terms of
--   the GNU General Public License version 3 or later.
--

-- RDF Data Model
CREATE TABLE resource (
	id INTEGER PRIMARY KEY AUTOINCREMENT,
	published_date TIMESTAMP WITH TIME ZONE -- received date with site tz
		DEFAULT CURRENT_TIMESTAMP NOT NULL,
	literal BOOLEAN DEFAULT false,
	uriref BOOLEAN DEFAULT false,
	label TEXT); -- literal value | external uriref | internal class name
	-- optimize: store external uriref hash in numeric field

CREATE INDEX resource_id_idx ON resource (id);
CREATE INDEX resource_uriref_idx ON resource (uriref);
CREATE INDEX resource_label_idx ON resource (label);
CREATE INDEX resource_published_date_idx ON resource (published_date);

CREATE TABLE statement (
	id INTEGER REFERENCES resource,
	subject INTEGER NOT NULL REFERENCES resource,
	predicate INTEGER NOT NULL REFERENCES resource,
	object INTEGER NOT NULL REFERENCES resource,
	rating NUMERIC(4,2)); -- computed from vote

CREATE INDEX statement_id_idx ON statement (id);
CREATE INDEX statement_subject_idx ON statement (subject);
CREATE INDEX statement_object_idx ON statement (object);

-- Members and Sessions
CREATE TABLE member (
	id INTEGER REFERENCES resource,
	login TEXT UNIQUE NOT NULL,
	full_name TEXT,
	email TEXT UNIQUE NOT NULL,
	password TEXT,
	prefs TEXT,
	confirm TEXT UNIQUE,
	session TEXT UNIQUE,
	login_time TIMESTAMP WITH TIME ZONE,
	last_time TIMESTAMP WITH TIME ZONE);

CREATE INDEX member_id_idx ON member (id);

-- Messages and Threads
CREATE TABLE message (
	id INTEGER REFERENCES resource,
	parent INTEGER REFERENCES message,   -- In-Reply-To:
	description INTEGER REFERENCES message,   -- abstract or toc or thumbnail
	version_of INTEGER REFERENCES message,   -- current version
	open BOOLEAN DEFAULT false,   -- editing open for all members
	hidden BOOLEAN DEFAULT false,   -- hidden from public view
	creator INTEGER REFERENCES member,   -- From:
	language TEXT,   -- language code
	title TEXT NOT NULL,   -- Subject:
	format TEXT,   -- MIME type
	content TEXT,
	html_full TEXT,
	html_short TEXT);

CREATE INDEX message_id_idx ON message (id);
CREATE INDEX message_parent_idx ON message (parent);
CREATE INDEX message_version_of_idx ON message (version_of);

-- Voting Data
CREATE TABLE vote (
	id INTEGER REFERENCES resource,
	proposition INTEGER REFERENCES statement,
	member INTEGER REFERENCES member,
	rating NUMERIC(2),
	UNIQUE (proposition, member));

CREATE INDEX vote_id_idx ON vote (id);
CREATE INDEX vote_proposition_idx ON vote (proposition);

-- Moderation Actions Log
CREATE TABLE moderation (
	action_date TIMESTAMP WITH TIME ZONE
		DEFAULT CURRENT_TIMESTAMP PRIMARY KEY,
	moderator INTEGER REFERENCES member,
	action TEXT,
	resource INTEGER REFERENCES resource);

CREATE INDEX moderation_action_date_idx ON moderation (action_date);
CREATE INDEX moderation_resource_idx ON moderation (resource);

-- Role-based Access Control
CREATE TABLE role (
	member INTEGER REFERENCES member,
	role TEXT);

CREATE INDEX role_member_idx ON role (member);
