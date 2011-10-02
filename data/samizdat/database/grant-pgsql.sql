-- Samizdat Database Grants - PostgreSQL
--
--   Copyright (c) 2002-2009  Dmitry Borodaenko <angdraug@debian.org>
--
--   This program is free software.
--   You can distribute/modify this program under the terms of
--   the GNU General Public License version 3 or later.
--

-- grant access to different user for maximum priviledge separation
GRANT INSERT, UPDATE, SELECT ON Resource, Statement, Vote, Member, Message,
	Tag, PendingUpload, PendingUploadFile
TO samizdat;
GRANT INSERT, UPDATE, DELETE, SELECT ON Part TO samizdat;
GRANT INSERT, SELECT ON Moderation TO samizdat;
GRANT SELECT ON Role TO samizdat;
GRANT USAGE, UPDATE, SELECT ON Resource_id_seq, PendingUpload_id_seq
TO samizdat;
