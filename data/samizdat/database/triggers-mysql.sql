-- Samizdat Database Triggers - MySQL
--
--   Copyright (c) 2002-2009  Dmitry Borodaenko <angdraug@debian.org>
--
--   This program is free software.
--   You can distribute/modify this program under the terms of
--   the GNU General Public License version 3 or later.
--

DELIMITER |

CREATE TRIGGER insert_statement BEFORE INSERT ON Statement
    FOR EACH ROW
    BEGIN
	IF NEW.id IS NULL OR NEW.id = 0 THEN
	    INSERT INTO Resource (literal, uriref, label)
		VALUES ('false', 'false', 'Statement');
	    SET NEW.id = (SELECT MAX(id) FROM Resource);
	END IF;
    END; |

CREATE TRIGGER insert_member BEFORE INSERT ON Member
    FOR EACH ROW
    BEGIN
	IF NEW.id IS NULL OR NEW.id = 0 THEN
	    INSERT INTO Resource (literal, uriref, label)
		VALUES ('false', 'false', 'Member');
	    SET NEW.id = (SELECT MAX(id) FROM Resource);
	END IF;
    END; |

CREATE TRIGGER insert_message BEFORE INSERT ON Message
    FOR EACH ROW
    BEGIN
	IF NEW.id IS NULL OR NEW.id = 0 THEN
	    INSERT INTO Resource (literal, uriref, label)
		VALUES ('false', 'false', 'Message');
	    SET NEW.id = (SELECT MAX(id) FROM Resource);
	END IF;
    END; |

CREATE TRIGGER insert_vote BEFORE INSERT ON Vote
    FOR EACH ROW
    BEGIN
	IF NEW.id IS NULL OR NEW.id = 0 THEN
	    INSERT INTO Resource (literal, uriref, label)
		VALUES ('false', 'false', 'Vote');
	    SET NEW.id = (SELECT MAX(id) FROM Resource);
	END IF;
    END; |

DELIMITER ;


CREATE TRIGGER delete_statement AFTER DELETE ON Statement
    FOR EACH ROW
    DELETE FROM Resource WHERE id = OLD.id;

CREATE TRIGGER delete_member AFTER DELETE ON Member
    FOR EACH ROW
    DELETE FROM Resource WHERE id = OLD.id;

CREATE TRIGGER delete_message AFTER DELETE ON Message
    FOR EACH ROW
    DELETE FROM Resource WHERE id = OLD.id;

CREATE TRIGGER delete_vote AFTER DELETE ON Vote
    FOR EACH ROW
    DELETE FROM Resource WHERE id = OLD.id;


CREATE TRIGGER insert_rating AFTER INSERT ON Vote
    FOR EACH ROW
    UPDATE Statement SET rating = (SELECT AVG(rating) FROM Vote
	WHERE proposition = NEW.proposition) WHERE id = NEW.proposition;

CREATE TRIGGER update_rating AFTER UPDATE ON Vote
    FOR EACH ROW
    UPDATE Statement SET rating = (SELECT AVG(rating) FROM Vote
	WHERE proposition = NEW.proposition) WHERE id = NEW.proposition;

