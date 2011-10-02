-- Samizdat Database Creation - SQLite3 (Experimental)
--
--   Copyright (c) 2002-2009  Dmitry Borodaenko <angdraug@debian.org>
--
--   This program is free software.
--   You can distribute/modify this program under the terms of
--   the GNU General Public License version 3 or later.
--

-- RDF Data Model
CREATE TABLE Resource (
	id INTEGER PRIMARY KEY AUTOINCREMENT,
	published_date TIMESTAMP WITH TIME ZONE -- received date with site tz
		DEFAULT CURRENT_TIMESTAMP NOT NULL,
	literal BOOLEAN DEFAULT false,
	uriref BOOLEAN DEFAULT false,
	label TEXT); -- literal value | external uriref | internal class name
	-- optimize: store external uriref hash in numeric field

CREATE INDEX Resource_id_idx ON Resource (id);
CREATE INDEX Resource_uriref_idx ON Resource (uriref);
CREATE INDEX Resource_label_idx ON Resource (label);
CREATE INDEX Resource_published_date_idx ON Resource (published_date);

CREATE TABLE Statement (
	id INTEGER REFERENCES Resource,
	subject INTEGER NOT NULL REFERENCES Resource,
	predicate INTEGER NOT NULL REFERENCES Resource,
	object INTEGER NOT NULL REFERENCES Resource,
	rating NUMERIC(4,2)); -- computed from Vote

CREATE INDEX Statement_id_idx ON Statement (id);
CREATE INDEX Statement_subject_idx ON Statement (subject);
CREATE INDEX Statement_object_idx ON Statement (object);

-- Members and Sessions
CREATE TABLE Member (
	id INTEGER REFERENCES Resource,
	login TEXT UNIQUE NOT NULL,
	full_name TEXT,
	email TEXT UNIQUE NOT NULL,
	password TEXT,
	prefs TEXT,
	confirm TEXT UNIQUE,
	session TEXT UNIQUE,
	login_time TIMESTAMP WITH TIME ZONE,
	last_time TIMESTAMP WITH TIME ZONE);

CREATE INDEX Member_id_idx ON Member (id);

-- Messages and Threads
CREATE TABLE Message (
	id INTEGER REFERENCES Resource,
	parent INTEGER REFERENCES Message,   -- In-Reply-To:
	description INTEGER REFERENCES Message,   -- abstract or toc or thumbnail
	version_of INTEGER REFERENCES Message,   -- current version
	open BOOLEAN DEFAULT false,   -- editing open for all members
	hidden BOOLEAN DEFAULT false,   -- hidden from public view
	creator INTEGER REFERENCES Member,   -- From:
	language TEXT,   -- language code
	title TEXT NOT NULL,   -- Subject:
	format TEXT,   -- MIME type
	content TEXT,
	html_full TEXT,
	html_short TEXT);

CREATE INDEX Message_id_idx ON Message (id);
CREATE INDEX Message_parent_idx ON Message (parent);
CREATE INDEX Message_version_of_idx ON Message (version_of);

-- Voting Data
CREATE TABLE Vote (
	id INTEGER REFERENCES Resource,
	proposition INTEGER REFERENCES Statement,
	member INTEGER REFERENCES Member,
	rating NUMERIC(2),
	UNIQUE (proposition, member));

CREATE INDEX Vote_id_idx ON Vote (id);
CREATE INDEX Vote_proposition_idx ON Vote (proposition);

-- Moderation Actions Log
CREATE TABLE Moderation (
	action_date TIMESTAMP WITH TIME ZONE
		DEFAULT CURRENT_TIMESTAMP PRIMARY KEY,
	moderator INTEGER REFERENCES Member,
	action TEXT,
	resource INTEGER REFERENCES Resource);

CREATE INDEX Moderation_action_date_idx ON Moderation (action_date);
CREATE INDEX Moderation_resource_idx ON Moderation (resource);

-- Role-based Access Control
CREATE TABLE Role (
	member INTEGER REFERENCES Member,
	role TEXT);

CREATE INDEX Role_member_idx ON Role (member);
