-- Samizdat Database Grants - MySQL
--
--   Copyright (c) 2002-2011  Dmitry Borodaenko <angdraug@debian.org>
--
--   This program is free software.
--   You can distribute/modify this program under the terms of
--   the GNU General Public License version 3 or later.
--

-- grant access to different use for maximum priviledge separation
GRANT INSERT, UPDATE, SELECT ON resource TO samizdat;
GRANT INSERT, UPDATE, SELECT ON statement TO samizdat;
GRANT INSERT, UPDATE, SELECT ON vote TO samizdat;
GRANT INSERT, UPDATE, SELECT ON member TO samizdat;
GRANT INSERT, UPDATE, SELECT ON message TO samizdat;
GRANT INSERT, UPDATE, SELECT ON role TO samizdat;

GRANT INSERT, SELECT ON moderation TO samizdat;
