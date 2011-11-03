-- Samizdat Database Triggers - SQLite3 (Experimental)
--
--   Copyright (c) 2002-2011  Dmitry Borodaenko <angdraug@debian.org>
--
--   This program is free software.
--   You can distribute/modify this program under the terms of
--   the GNU General Public License version 3 or later.
--

CREATE TRIGGER insert_statement AFTER INSERT ON Statement
    FOR EACH ROW WHEN NEW.id IS NULL
    BEGIN
	INSERT INTO Resource (literal, uriref, label)
	    VALUES ('false', 'false', 'Statement');
	UPDATE Statement SET id = (SELECT MAX(id) FROM Resource)
	    WHERE rowid = NEW.rowid;
    END;

CREATE TRIGGER insert_member AFTER INSERT ON Member
    FOR EACH ROW WHEN NEW.id IS NULL
    BEGIN
	INSERT INTO Resource (literal, uriref, label)
	    VALUES ('false', 'false', 'Member');
	UPDATE Member SET id = (SELECT MAX(id) FROM Resource)
	    WHERE rowid = NEW.rowid;
    END;

CREATE TRIGGER insert_message AFTER INSERT ON Message
    FOR EACH ROW WHEN NEW.id IS NULL
    BEGIN
	INSERT INTO Resource (literal, uriref, label)
	    VALUES ('false', 'false', 'Message');
	UPDATE Message SET id = (SELECT MAX(id) FROM Resource)
	    WHERE rowid = NEW.rowid;
    END;

CREATE TRIGGER insert_vote AFTER INSERT ON Vote
    FOR EACH ROW WHEN NEW.id IS NULL
    BEGIN
	INSERT INTO Resource (literal, uriref, label)
	    VALUES ('false', 'false', 'Vote');
	UPDATE Vote SET id = (SELECT MAX(id) FROM Resource)
	    WHERE rowid = NEW.rowid;
    END;


CREATE TRIGGER delete_statement AFTER DELETE ON Statement
    FOR EACH ROW
    BEGIN
	DELETE FROM Resource WHERE id = OLD.id;
    END;

CREATE TRIGGER delete_member AFTER DELETE ON Member
    FOR EACH ROW
    BEGIN
	DELETE FROM Resource WHERE id = OLD.id;
    END;

CREATE TRIGGER delete_message AFTER DELETE ON Message
    FOR EACH ROW
    BEGIN
	DELETE FROM Resource WHERE id = OLD.id;
    END;

CREATE TRIGGER delete_vote AFTER DELETE ON Vote
    FOR EACH ROW
    BEGIN
	DELETE FROM Resource WHERE id = OLD.id;
    END;


CREATE TRIGGER insert_rating AFTER INSERT ON Vote
    FOR EACH ROW
    BEGIN
        UPDATE Statement SET rating = (SELECT AVG(rating) FROM Vote
	    WHERE proposition = NEW.proposition) WHERE id = NEW.proposition;
    END;

CREATE TRIGGER update_rating AFTER UPDATE ON Vote
    FOR EACH ROW
    BEGIN
        UPDATE Statement SET rating = (SELECT AVG(rating) FROM Vote
	    WHERE proposition = NEW.proposition) WHERE id = NEW.proposition;
    END;

