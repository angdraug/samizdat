-- Samizdat Database Creation - PostgreSQL
--
--   Copyright (c) 2002-2011  Dmitry Borodaenko <angdraug@debian.org>
--
--   This program is free software.
--   You can distribute/modify this program under the terms of
--   the GNU General Public License version 3 or later.
--

-- RDF Data Model
CREATE TABLE Resource (
	id SERIAL PRIMARY KEY,
	published_date TIMESTAMP WITH TIME ZONE -- received date with site tz
		DEFAULT CURRENT_TIMESTAMP NOT NULL,

	-- parent resource (subproperty of dct:isPartOf)
	part_of INTEGER REFERENCES Resource,
	part_of_subproperty INTEGER REFERENCES Resource,
	part_sequence_number INTEGER,

	-- resource type and value
	literal BOOLEAN DEFAULT false,
	uriref BOOLEAN DEFAULT false,
	label TEXT); -- literal value | external uriref | internal class name
	-- optimize: store external uriref hash in numeric field

CREATE INDEX Resource_uriref_idx ON Resource (uriref);
CREATE INDEX Resource_label_idx ON Resource (label);
CREATE INDEX Resource_published_date_idx ON Resource (published_date);
CREATE INDEX Resource_part_of_idx ON Resource (part_of);

CREATE TABLE Statement (
	id INTEGER PRIMARY KEY REFERENCES Resource,
	subject INTEGER NOT NULL REFERENCES Resource,
	predicate INTEGER NOT NULL REFERENCES Resource,
	object INTEGER NOT NULL REFERENCES Resource,
	rating NUMERIC(4,2)); -- computed from Vote

CREATE INDEX Statement_subject_idx ON Statement (subject);
CREATE INDEX Statement_object_idx ON Statement (object);

-- Members and Sessions
CREATE TABLE Member (
	id INTEGER PRIMARY KEY REFERENCES Resource,
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
CREATE TABLE Message (
	id INTEGER PRIMARY KEY REFERENCES Resource,
	open BOOLEAN DEFAULT false,   -- editing open for all members
	hidden BOOLEAN DEFAULT false,   -- hidden from public view
	locked BOOLEAN,
	creator INTEGER REFERENCES Member,   -- From:
	language TEXT,   -- language code
	title TEXT,   -- Subject:
	format TEXT,   -- MIME type
	content TEXT,
	html_full TEXT,
	html_short TEXT);

CREATE INDEX Message_parent_idx ON Message (parent);
CREATE INDEX Message_version_of_idx ON Message (version_of);

-- Voting Data
CREATE TABLE Vote (
	id INTEGER PRIMARY KEY REFERENCES Resource,
	proposition INTEGER REFERENCES Statement,
	member INTEGER REFERENCES Member,
	rating NUMERIC(2),
	UNIQUE (proposition, member));

CREATE INDEX Vote_proposition_idx ON Vote (proposition);

-- Moderation Actions Log
CREATE TABLE Moderation (
	action_date TIMESTAMP WITH TIME ZONE
		DEFAULT CURRENT_TIMESTAMP PRIMARY KEY,
	moderator INTEGER REFERENCES Member,
	action TEXT,
	resource INTEGER REFERENCES Resource);

CREATE INDEX Moderation_resource_idx ON Moderation (resource);

-- Role-based Access Control
CREATE TABLE Role (
	member INTEGER REFERENCES Member,
	role TEXT);

CREATE INDEX Role_member_idx ON Role (member);

-- Transitive Parts Lookup Table
CREATE TABLE Part (
	id INTEGER REFERENCES Resource,
	part_of INTEGER REFERENCES Resource,
	part_of_subproperty INTEGER REFERENCES Resource,
	distance INTEGER DEFAULT 0 NOT NULL);

CREATE INDEX Part_resource_idx ON Part (id);
CREATE INDEX Part_part_of_idx ON Part (part_of);

-- Tag Cache
CREATE TABLE Tag (
	id INTEGER PRIMARY KEY REFERENCES Resource,
	nrelated INTEGER,
	nrelated_with_subtags INTEGER);

-- Pending Uploads Queue
CREATE TYPE PendingUploadStatus AS ENUM ('pending', 'confirmed', 'expired');

CREATE TABLE PendingUpload (
	id SERIAL PRIMARY KEY,
	created_date TIMESTAMP WITH TIME ZONE
		DEFAULT CURRENT_TIMESTAMP NOT NULL,
	login TEXT NOT NULL,
	status PendingUploadStatus DEFAULT 'pending' NOT NULL);

CREATE INDEX PendingUpload_status_idx ON PendingUpload (login, status);

CREATE TABLE PendingUploadFile (
	upload INTEGER NOT NULL REFERENCES PendingUpload,
	part INTEGER,
	UNIQUE (upload, part),
	format TEXT,
	original_filename TEXT);

CREATE INDEX PendingUploadFile_upload_idx ON PendingUploadFile (upload);
