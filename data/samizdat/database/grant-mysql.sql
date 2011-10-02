-- Samizdat Database Grants - MySQL
--
--   Copyright (c) 2002-2009  Dmitry Borodaenko <angdraug@debian.org>
--
--   This program is free software.
--   You can distribute/modify this program under the terms of
--   the GNU General Public License version 3 or later.
--

-- grant access to different use for maximum priviledge separation
GRANT INSERT, UPDATE, SELECT ON Resource TO samizdat;
GRANT INSERT, UPDATE, SELECT ON Statement TO samizdat;
GRANT INSERT, UPDATE, SELECT ON Vote TO samizdat;
GRANT INSERT, UPDATE, SELECT ON Member TO samizdat;
GRANT INSERT, UPDATE, SELECT ON Message TO samizdat;
GRANT INSERT, UPDATE, SELECT ON Role TO samizdat;

GRANT INSERT, SELECT ON Moderation TO samizdat;
