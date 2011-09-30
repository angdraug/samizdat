-- Samizdat Database Triggers - MySQL
--
--   Copyright (c) 2002-2011  Dmitry Borodaenko <angdraug@debian.org>
--
--   This program is free software.
--   You can distribute/modify this program under the terms of
--   the GNU General Public License version 3 or later.
--

DELIMITER |

CREATE TRIGGER insert_statement BEFORE INSERT ON statement
    FOR EACH ROW
    BEGIN
	IF NEW.id IS NULL OR NEW.id = 0 THEN
	    INSERT INTO resource (literal, uriref, label)
		VALUES ('false', 'false', 'statement');
	    SET NEW.id = (SELECT MAX(id) FROM resource);
	END IF;
    END; |

CREATE TRIGGER insert_member BEFORE INSERT ON member
    FOR EACH ROW
    BEGIN
	IF NEW.id IS NULL OR NEW.id = 0 THEN
	    INSERT INTO resource (literal, uriref, label)
		VALUES ('false', 'false', 'member');
	    SET NEW.id = (SELECT MAX(id) FROM resource);
	END IF;
    END; |

CREATE TRIGGER insert_message BEFORE INSERT ON message
    FOR EACH ROW
    BEGIN
	IF NEW.id IS NULL OR NEW.id = 0 THEN
	    INSERT INTO resource (literal, uriref, label)
		VALUES ('false', 'false', 'message');
	    SET NEW.id = (SELECT MAX(id) FROM resource);
	END IF;
    END; |

CREATE TRIGGER insert_vote BEFORE INSERT ON vote
    FOR EACH ROW
    BEGIN
	IF NEW.id IS NULL OR NEW.id = 0 THEN
	    INSERT INTO resource (literal, uriref, label)
		VALUES ('false', 'false', 'vote');
	    SET NEW.id = (SELECT MAX(id) FROM resource);
	END IF;
    END; |

DELIMITER ;


CREATE TRIGGER delete_statement AFTER DELETE ON statement
    FOR EACH ROW
    DELETE FROM resource WHERE id = OLD.id;

CREATE TRIGGER delete_member AFTER DELETE ON member
    FOR EACH ROW
    DELETE FROM resource WHERE id = OLD.id;

CREATE TRIGGER delete_message AFTER DELETE ON message
    FOR EACH ROW
    DELETE FROM resource WHERE id = OLD.id;

CREATE TRIGGER delete_vote AFTER DELETE ON vote
    FOR EACH ROW
    DELETE FROM resource WHERE id = OLD.id;


CREATE TRIGGER insert_rating AFTER INSERT ON vote
    FOR EACH ROW
    UPDATE statement SET rating = (SELECT AVG(rating) FROM vote
	WHERE proposition = NEW.proposition) WHERE id = NEW.proposition;

CREATE TRIGGER update_rating AFTER UPDATE ON vote
    FOR EACH ROW
    UPDATE statement SET rating = (SELECT AVG(rating) FROM vote
	WHERE proposition = NEW.proposition) WHERE id = NEW.proposition;

