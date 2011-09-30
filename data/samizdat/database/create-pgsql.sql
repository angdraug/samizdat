-- Samizdat Database Creation - PostgreSQL
--
--   Copyright (c) 2002-2011  Dmitry Borodaenko <angdraug@debian.org>
--
--   This program is free software.
--   You can distribute/modify this program under the terms of
--   the GNU General Public License version 3 or later.
--

-- RDF Data Model
CREATE TABLE resource (
	id SERIAL PRIMARY KEY,
	published_date TIMESTAMP WITH TIME ZONE -- received date with site tz
		DEFAULT CURRENT_TIMESTAMP NOT NULL,

	-- parent resource (subproperty of dct:isPartOf)
	part_of INTEGER REFERENCES resource,
	part_of_subproperty INTEGER REFERENCES resource,
	part_sequence_number INTEGER,

	-- resource type and value
	literal BOOLEAN DEFAULT false,
	uriref BOOLEAN DEFAULT false,
	label TEXT); -- literal value | external uriref | internal class name
	-- optimize: store external uriref hash in numeric field

CREATE INDEX resource_uriref_idx ON resource (uriref);
CREATE INDEX resource_label_idx ON resource (label);
CREATE INDEX resource_published_date_idx ON resource (published_date);
CREATE INDEX resource_part_of_idx ON resource (part_of);

CREATE TABLE statement (
	id INTEGER PRIMARY KEY REFERENCES resource,
	subject INTEGER NOT NULL REFERENCES resource,
	predicate INTEGER NOT NULL REFERENCES resource,
	object INTEGER NOT NULL REFERENCES resource,
	rating NUMERIC(4,2)); -- computed from vote

CREATE INDEX statement_subject_idx ON statement (subject);
CREATE INDEX statement_object_idx ON statement (object);

-- Members and Sessions
CREATE TABLE member (
	id INTEGER PRIMARY KEY REFERENCES resource,
	login TEXT UNIQUE NOT NULL,
	full_name TEXT,
	email TEXT UNIQUE NOT NULL,
	password TEXT,
	prefs TEXT,
	confirm TEXT UNIQUE,
	session TEXT UNIQUE,
	login_time TIMESTAMP WITH TIME ZONE,
	last_time TIMESTAMP WITH TIME ZONE);

-- Messages and Threads
CREATE TABLE message (
	id INTEGER PRIMARY KEY REFERENCES resource,
	open BOOLEAN DEFAULT false,   -- editing open for all members
	hidden BOOLEAN DEFAULT false,   -- hidden from public view
	locked BOOLEAN,
	creator INTEGER REFERENCES member,   -- From:
	language TEXT,   -- language code
	title TEXT,   -- Subject:
	format TEXT,   -- MIME type
	content TEXT,
	html_full TEXT,
	html_short TEXT);

CREATE INDEX message_parent_idx ON message (parent);
CREATE INDEX message_version_of_idx ON message (version_of);

-- Voting Data
CREATE TABLE vote (
	id INTEGER PRIMARY KEY REFERENCES resource,
	proposition INTEGER REFERENCES statement,
	member INTEGER REFERENCES member,
	rating NUMERIC(2),
	UNIQUE (proposition, member));

CREATE INDEX vote_proposition_idx ON vote (proposition);

-- Moderation Actions Log
CREATE TABLE moderation (
	action_date TIMESTAMP WITH TIME ZONE
		DEFAULT CURRENT_TIMESTAMP PRIMARY KEY,
	moderator INTEGER REFERENCES member,
	action TEXT,
	resource INTEGER REFERENCES resource);

CREATE INDEX moderation_resource_idx ON moderation (resource);

-- Role-based Access Control
CREATE TABLE role (
	member INTEGER REFERENCES member,
	role TEXT);

CREATE INDEX role_member_idx ON role (member);

-- Transitive Parts Lookup Table
CREATE TABLE part (
	id INTEGER REFERENCES resource,
	part_of INTEGER REFERENCES resource,
	part_of_subproperty INTEGER REFERENCES resource,
	distance INTEGER DEFAULT 0 NOT NULL);

CREATE INDEX part_resource_idx ON part (id);
CREATE INDEX part_part_of_idx ON part (part_of);

-- Tag Cache
CREATE TABLE tag (
	id INTEGER PRIMARY KEY REFERENCES resource,
	nrelated INTEGER,
	nrelated_with_subtags INTEGER);

-- Pending Uploads Queue
CREATE TYPE pending_upload_status AS ENUM ('pending', 'confirmed', 'expired');

CREATE TABLE pending_upload (
	id SERIAL PRIMARY KEY,
	created_date TIMESTAMP WITH TIME ZONE
		DEFAULT CURRENT_TIMESTAMP NOT NULL,
	login TEXT NOT NULL,
	status pending_upload_status DEFAULT 'pending' NOT NULL);

CREATE INDEX pending_upload_status_idx ON pending_upload (login, status);

CREATE TABLE pending_upload_file (
	upload INTEGER NOT NULL REFERENCES pending_upload,
	part INTEGER,
	UNIQUE (upload, part),
	format TEXT,
	original_filename TEXT);

CREATE INDEX pending_upload_file_upload_idx ON pending_upload_file (upload);
