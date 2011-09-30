-- Samizdat Database Creation - MySQL
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
	published_date TIMESTAMP -- received date
		DEFAULT CURRENT_TIMESTAMP NOT NULL,
	literal ENUM ('true', 'false') DEFAULT 'false',
	uriref ENUM ('true', 'false') DEFAULT 'false',
	label VARCHAR(255)) -- literal value | external uriref | internal class name
	-- optimize: store external uriref hash in numeric field
ENGINE InnoDB DEFAULT CHARACTER SET binary;

CREATE INDEX resource_uriref_idx ON resource (uriref);
CREATE INDEX resource_label_idx ON resource (label);
CREATE INDEX resource_published_date_idx ON resource (published_date);

CREATE TABLE statement (
	id INTEGER PRIMARY KEY REFERENCES resource,
	subject INTEGER NOT NULL REFERENCES resource,
	predicate INTEGER NOT NULL REFERENCES resource,
	object INTEGER NOT NULL REFERENCES resource,
	rating NUMERIC(4,2)) -- computed from vote
ENGINE InnoDB DEFAULT CHARACTER SET binary;

CREATE INDEX statement_subject_idx ON statement (subject);
CREATE INDEX statement_object_idx ON statement (object);

-- Members and Sessions
CREATE TABLE member (
	id INTEGER PRIMARY KEY REFERENCES resource,
	login VARCHAR(255) UNIQUE NOT NULL,
	full_name TEXT,
	email VARCHAR(255) UNIQUE NOT NULL,
	password VARCHAR(255),
	prefs TEXT,
	confirm VARCHAR(255) UNIQUE,
	session VARCHAR(255) UNIQUE,
	login_time TIMESTAMP DEFAULT '0000-00-00 00:00:00',
	last_time TIMESTAMP DEFAULT '0000-00-00 00:00:00')
ENGINE InnoDB DEFAULT CHARACTER SET binary;

-- Messages and Threads
CREATE TABLE message (
	id INTEGER PRIMARY KEY REFERENCES resource,
	parent INTEGER REFERENCES message,   -- In-Reply-To:
	description INTEGER REFERENCES message,   -- abstract or toc or thumbnail
	version_of INTEGER REFERENCES message,   -- current version
	open ENUM ('true', 'false') DEFAULT 'false',   -- editing open for all members
	hidden ENUM ('true', 'false') DEFAULT 'false',   -- hidden from public view
	creator INTEGER REFERENCES member,   -- From:
	language VARCHAR(255),   -- language code
	title TEXT NOT NULL,   -- Subject:
	format TEXT,   -- MIME type
	content TEXT,
	html_full TEXT,
	html_short TEXT)
ENGINE InnoDB DEFAULT CHARACTER SET binary;

CREATE INDEX message_parent_idx ON message (parent);
CREATE INDEX message_version_of_idx ON message (version_of);

-- Voting Data
CREATE TABLE vote (
	id INTEGER PRIMARY KEY REFERENCES resource,
	proposition INTEGER REFERENCES statement,
	member INTEGER REFERENCES member,
	rating NUMERIC(2),
	UNIQUE (proposition, member))
ENGINE InnoDB DEFAULT CHARACTER SET binary;

CREATE INDEX vote_proposition_idx ON vote (proposition);

-- Moderation Actions Log
CREATE TABLE moderation (
	action_date TIMESTAMP
		DEFAULT CURRENT_TIMESTAMP PRIMARY KEY,
	moderator INTEGER REFERENCES member,
	action VARCHAR(255),
	resource INTEGER REFERENCES resource)
ENGINE InnoDB DEFAULT CHARACTER SET binary;

CREATE INDEX moderation_resource_idx ON moderation (resource);

-- Role-based Access Control
CREATE TABLE role (
	member INTEGER REFERENCES member,
	role VARCHAR(255))
ENGINE InnoDB DEFAULT CHARACTER SET binary;

CREATE INDEX role_member_idx ON role (member);
