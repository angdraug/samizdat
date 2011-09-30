-- Samizdat Database Triggers - SQLite3 (Experimental)
--
--   Copyright (c) 2002-2011  Dmitry Borodaenko <angdraug@debian.org>
--
--   This program is free software.
--   You can distribute/modify this program under the terms of
--   the GNU General Public License version 3 or later.
--

CREATE TRIGGER insert_statement AFTER INSERT ON statement
    FOR EACH ROW WHEN NEW.id IS NULL
    BEGIN
	INSERT INTO resource (literal, uriref, label)
	    VALUES ('false', 'false', 'statement');
	UPDATE statement SET id = (SELECT MAX(id) FROM resource)
	    WHERE rowid = NEW.rowid;
    END;

CREATE TRIGGER insert_member AFTER INSERT ON member
    FOR EACH ROW WHEN NEW.id IS NULL
    BEGIN
	INSERT INTO resource (literal, uriref, label)
	    VALUES ('false', 'false', 'member');
	UPDATE member SET id = (SELECT MAX(id) FROM resource)
	    WHERE rowid = NEW.rowid;
    END;

CREATE TRIGGER insert_message AFTER INSERT ON message
    FOR EACH ROW WHEN NEW.id IS NULL
    BEGIN
	INSERT INTO resource (literal, uriref, label)
	    VALUES ('false', 'false', 'message');
	UPDATE message SET id = (SELECT MAX(id) FROM resource)
	    WHERE rowid = NEW.rowid;
    END;

CREATE TRIGGER insert_vote AFTER INSERT ON vote
    FOR EACH ROW WHEN NEW.id IS NULL
    BEGIN
	INSERT INTO resource (literal, uriref, label)
	    VALUES ('false', 'false', 'vote');
	UPDATE vote SET id = (SELECT MAX(id) FROM resource)
	    WHERE rowid = NEW.rowid;
    END;


CREATE TRIGGER delete_statement AFTER DELETE ON statement
    FOR EACH ROW
    BEGIN
	DELETE FROM resource WHERE id = OLD.id;
    END;

CREATE TRIGGER delete_member AFTER DELETE ON member
    FOR EACH ROW
    BEGIN
	DELETE FROM resource WHERE id = OLD.id;
    END;

CREATE TRIGGER delete_message AFTER DELETE ON message
    FOR EACH ROW
    BEGIN
	DELETE FROM resource WHERE id = OLD.id;
    END;

CREATE TRIGGER delete_vote AFTER DELETE ON vote
    FOR EACH ROW
    BEGIN
	DELETE FROM resource WHERE id = OLD.id;
    END;


CREATE TRIGGER insert_rating AFTER INSERT ON vote
    FOR EACH ROW
    BEGIN
        UPDATE statement SET rating = (SELECT AVG(rating) FROM vote
	    WHERE proposition = NEW.proposition) WHERE id = NEW.proposition;
    END;

CREATE TRIGGER update_rating AFTER UPDATE ON vote
    FOR EACH ROW
    BEGIN
        UPDATE statement SET rating = (SELECT AVG(rating) FROM vote
	    WHERE proposition = NEW.proposition) WHERE id = NEW.proposition;
    END;

