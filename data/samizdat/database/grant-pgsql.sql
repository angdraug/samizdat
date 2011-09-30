-- Samizdat Database Grants - PostgreSQL
--
--   Copyright (c) 2002-2011  Dmitry Borodaenko <angdraug@debian.org>
--
--   This program is free software.
--   You can distribute/modify this program under the terms of
--   the GNU General Public License version 3 or later.
--

-- grant access to different user for maximum priviledge separation
GRANT INSERT, UPDATE, SELECT ON resource, statement, vote, member, message,
	tag, pending_upload, pending_upload_file
TO samizdat;
GRANT INSERT, UPDATE, DELETE, SELECT ON part TO samizdat;
GRANT INSERT, SELECT ON moderation TO samizdat;
GRANT SELECT ON role TO samizdat;
GRANT USAGE, UPDATE, SELECT ON resource_id_seq, pending_upload_id_seq
TO samizdat;
