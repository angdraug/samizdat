-- Samizdat Database Creation - MySQL
--
--   Copyright (c) 2002-2009  Dmitry Borodaenko <angdraug@debian.org>
--
--   This program is free software.
--   You can distribute/modify this program under the terms of
--   the GNU General Public License version 3 or later.
--

-- RDF Data Model
CREATE TABLE Resource (
	id SERIAL PRIMARY KEY,
	published_date TIMESTAMP -- received date
		DEFAULT CURRENT_TIMESTAMP NOT NULL,
	literal ENUM ('true', 'false') DEFAULT 'false',
	uriref ENUM ('true', 'false') DEFAULT 'false',
	label VARCHAR(255)) -- literal value | external uriref | internal class name
	-- optimize: store external uriref hash in numeric field
ENGINE InnoDB DEFAULT CHARACTER SET binary;

CREATE INDEX Resource_uriref_idx ON Resource (uriref);
CREATE INDEX Resource_label_idx ON Resource (label);
CREATE INDEX Resource_published_date_idx ON Resource (published_date);

CREATE TABLE Statement (
	id INTEGER PRIMARY KEY REFERENCES Resource,
	subject INTEGER NOT NULL REFERENCES Resource,
	predicate INTEGER NOT NULL REFERENCES Resource,
	object INTEGER NOT NULL REFERENCES Resource,
	rating NUMERIC(4,2)) -- computed from Vote
ENGINE InnoDB DEFAULT CHARACTER SET binary;

CREATE INDEX Statement_subject_idx ON Statement (subject);
CREATE INDEX Statement_object_idx ON Statement (object);

-- Members and Sessions
CREATE TABLE Member (
	id INTEGER PRIMARY KEY REFERENCES Resource,
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
CREATE TABLE Message (
	id INTEGER PRIMARY KEY REFERENCES Resource,
	parent INTEGER REFERENCES Message,   -- In-Reply-To:
	description INTEGER REFERENCES Message,   -- abstract or toc or thumbnail
	version_of INTEGER REFERENCES Message,   -- current version
	open ENUM ('true', 'false') DEFAULT 'false',   -- editing open for all members
	hidden ENUM ('true', 'false') DEFAULT 'false',   -- hidden from public view
	creator INTEGER REFERENCES Member,   -- From:
	language VARCHAR(255),   -- language code
	title TEXT NOT NULL,   -- Subject:
	format TEXT,   -- MIME type
	content TEXT,
	html_full TEXT,
	html_short TEXT)
ENGINE InnoDB DEFAULT CHARACTER SET binary;

CREATE INDEX Message_parent_idx ON Message (parent);
CREATE INDEX Message_version_of_idx ON Message (version_of);

-- Voting Data
CREATE TABLE Vote (
	id INTEGER PRIMARY KEY REFERENCES Resource,
	proposition INTEGER REFERENCES Statement,
	member INTEGER REFERENCES Member,
	rating NUMERIC(2),
	UNIQUE (proposition, member))
ENGINE InnoDB DEFAULT CHARACTER SET binary;

CREATE INDEX Vote_proposition_idx ON Vote (proposition);

-- Moderation Actions Log
CREATE TABLE Moderation (
	action_date TIMESTAMP
		DEFAULT CURRENT_TIMESTAMP PRIMARY KEY,
	moderator INTEGER REFERENCES Member,
	action VARCHAR(255),
	resource INTEGER REFERENCES Resource)
ENGINE InnoDB DEFAULT CHARACTER SET binary;

CREATE INDEX Moderation_resource_idx ON Moderation (resource);

-- Material Items Sharing
CREATE TABLE Item (
	id INTEGER PRIMARY KEY REFERENCES Resource,
	description INTEGER REFERENCES Message,
	contributor INTEGER REFERENCES Member,
	possessor INTEGER REFERENCES Member)
ENGINE InnoDB DEFAULT CHARACTER SET binary;

CREATE TABLE Possession (
	id INTEGER PRIMARY KEY REFERENCES Resource,
	item INTEGER REFERENCES Item,
	taken_from INTEGER REFERENCES Member,
	given_to INTEGER REFERENCES Member)
ENGINE InnoDB DEFAULT CHARACTER SET binary;

-- Role-based Access Control
CREATE TABLE Role (
	member INTEGER REFERENCES Member,
	role VARCHAR(255))
ENGINE InnoDB DEFAULT CHARACTER SET binary;

CREATE INDEX Role_member_idx ON Role (member);
