-- Samizdat Database Migration from v0.6.2 - PostgreSQL
--
--   Copyright (c) 2002-2011  Dmitry Borodaenko <angdraug@debian.org>
--
--   This program is free software.
--   You can distribute/modify this program under the terms of
--   the GNU General Public License version 3 or later.
--

BEGIN;

-- update tables

ALTER TABLE member
        ALTER COLUMN full_name DROP NOT NULL;

ALTER TABLE message
        ADD COLUMN locked BOOLEAN;

ALTER TABLE resource
        ADD COLUMN part_of INTEGER REFERENCES resource,
        ADD COLUMN part_of_subproperty INTEGER REFERENCES resource,
        ADD COLUMN part_sequence_number INTEGER;

CREATE INDEX resource_part_of_idx ON resource (part_of);

REVOKE INSERT, UPDATE ON role FROM samizdat;

-- create new tables

CREATE TABLE part (
        id INTEGER REFERENCES resource,
        part_of INTEGER REFERENCES resource,
        part_of_subproperty INTEGER REFERENCES resource,
        distance INTEGER DEFAULT 0 NOT NULL);

CREATE INDEX part_id_idx ON part (id);
CREATE INDEX part_part_of_idx ON part (part_of);

CREATE TABLE tag (
        id INTEGER PRIMARY KEY REFERENCES resource,
        nrelated INTEGER,
        nrelated_with_subtags INTEGER);

CREATE TYPE pending_upload_status AS ENUM ('pending', 'confirmed', 'expired');

CREATE TABLE pending_upload (
        id SERIAL PRIMARY KEY,
        created_date TIMESTAMP WITH TIME ZONE
                DEFAULT CURRENT_TIMESTAMP NOT NULL,
        login TEXT NOT NULL,
        status pending_upload_status DEFAULT 'pending' NOT NULL);

CREATE INDEX pending_upload_status_idx ON pending_upload (login, status);

CREATE TABLE pending_upload_file (
        upload INTEGER NOT NULL REFERENCES pending_upload,
        part INTEGER,
        UNIQUE (upload, part),
        format TEXT,
        original_filename TEXT);

CREATE INDEX pending_upload_file_upload_idx ON pending_upload_file (upload);

-- grant access to new tables (change samizdat to your user if different)

GRANT INSERT, UPDATE, SELECT ON tag,
        pending_upload, pending_upload_file TO samizdat;
GRANT INSERT, UPDATE, DELETE, SELECT ON part TO samizdat;
GRANT USAGE, UPDATE, SELECT ON pending_upload_id_seq TO samizdat;

-- update triggers

DROP FUNCTION update_rating() CASCADE;

CREATE FUNCTION select_subproperty(value resource.id%TYPE, subproperty resource.id%TYPE) RETURNS resource.id%TYPE AS $$
    BEGIN
        IF subproperty IS NULL THEN
            RETURN NULL;
        ELSE
            RETURN value;
        END IF;
    END;
$$ LANGUAGE 'plpgsql';

CREATE FUNCTION calculate_statement_rating(statement_id statement.id%TYPE) RETURNS statement.rating%TYPE AS $$
    BEGIN
        RETURN (SELECT AVG(rating) FROM vote WHERE proposition = statement_id);
    END;
$$ LANGUAGE 'plpgsql';

CREATE FUNCTION update_nrelated(tag_id resource.id%TYPE) RETURNS VOID AS $$
    DECLARE
        dc_relation resource.label%TYPE := 'http://purl.org/dc/elements/1.1/relation';
        s_subtag_of resource.label%TYPE := 'http://www.nongnu.org/samizdat/rdf/schema#subTagOf';
        s_subtag_of_id resource.id%TYPE;
        n tag.nrelated%TYPE;
        supertag RECORD;
    BEGIN
        -- update nrelated
        SELECT COUNT(*) INTO n
            FROM statement s
            INNER JOIN resource p ON s.predicate = p.id
            WHERE p.label = dc_relation AND s.object = tag_id AND s.rating > 0;

        UPDATE tag SET nrelated = n WHERE id = tag_id;
        IF NOT FOUND THEN
            INSERT INTO tag (id, nrelated) VALUES (tag_id, n);
        END IF;

        -- update nrelated_with_subtags for this tag and its supertags
        SELECT id INTO s_subtag_of_id FROM resource
            WHERE label = s_subtag_of;

        FOR supertag IN (
            SELECT tag_id AS id, 0 AS distance
                UNION
                SELECT part_of AS id, distance FROM part
                    WHERE id = tag_id
                    AND part_of_subproperty = s_subtag_of_id
                ORDER BY distance ASC)
        LOOP
            UPDATE tag
                SET nrelated_with_subtags = nrelated + COALESCE((
                    SELECT SUM(subt.nrelated)
                        FROM part p
                        INNER JOIN tag subt ON subt.id = p.id
                        WHERE p.part_of = supertag.id
                        AND p.part_of_subproperty = s_subtag_of_id), 0)
                WHERE id = supertag.id;
        END LOOP;
    END;
$$ LANGUAGE 'plpgsql';

CREATE FUNCTION update_nrelated_if_subtag(tag_id resource.id%TYPE, property resource.id%TYPE) RETURNS VOID AS $$
    DECLARE
        s_subtag_of resource.label%TYPE := 'http://www.nongnu.org/samizdat/rdf/schema#subTagOf';
        s_subtag_of_id resource.id%TYPE;
    BEGIN
        SELECT id INTO s_subtag_of_id FROM resource
            WHERE label = s_subtag_of;

        IF property = s_subtag_of_id THEN
            PERFORM update_nrelated(tag_id);
        END IF;
    END;
$$ LANGUAGE 'plpgsql';

CREATE FUNCTION update_rating() RETURNS TRIGGER AS $$
    DECLARE
        dc_relation resource.label%TYPE := 'http://purl.org/dc/elements/1.1/relation';
        old_rating statement.rating%TYPE;
        new_rating statement.rating%TYPE;
        tag_id resource.id%TYPE;
        predicate_uriref resource.label%TYPE;
    BEGIN
        -- save some values for later reference
        SELECT s.rating, s.object, p.label
            INTO old_rating, tag_id, predicate_uriref
            FROM statement s
            INNER JOIN resource p ON s.predicate = p.id
            WHERE s.id = NEW.proposition;

        -- set new rating of the proposition
        new_rating := calculate_statement_rating(NEW.proposition);
        UPDATE statement SET rating = new_rating WHERE id = NEW.proposition;

        -- check if new rating reverts truth value of the proposition
        IF predicate_uriref = dc_relation
            AND (((old_rating IS NULL OR old_rating <= 0) AND new_rating > 0) OR
                (old_rating > 0 AND new_rating <= 0))
        THEN
            PERFORM update_nrelated(tag_id);
        END IF;

        RETURN NEW;
    END;
$$ LANGUAGE 'plpgsql';

CREATE TRIGGER update_rating AFTER INSERT OR UPDATE OR DELETE ON vote
    FOR EACH ROW EXECUTE PROCEDURE update_rating();

CREATE FUNCTION before_update_part() RETURNS TRIGGER AS $$
    BEGIN
        IF TG_OP = 'INSERT' THEN
            IF NEW.part_of IS NULL THEN
                RETURN NEW;
            END IF;
        ELSIF TG_OP = 'UPDATE' THEN
            IF (NEW.part_of IS NULL AND OLD.part_of IS NULL) OR
                ((NEW.part_of = OLD.part_of) AND (NEW.part_of_subproperty = OLD.part_of_subproperty))
            THEN
                -- part_of is unchanged, do nothing
                RETURN NEW;
            END IF;
        END IF;

        -- check for loops
        IF NEW.part_of = NEW.id OR NEW.part_of IN (
            SELECT id FROM part WHERE part_of = NEW.id)
        THEN
            -- unset part_of, but don't fail whole query
            NEW.part_of = NULL;
            NEW.part_of_subproperty = NULL;

            IF TG_OP != 'INSERT' THEN
                -- check it was a subtag link
                PERFORM update_nrelated_if_subtag(OLD.id, OLD.part_of_subproperty);
            END IF;

            RETURN NEW;
        END IF;

        RETURN NEW;
    END;
$$ LANGUAGE 'plpgsql';

CREATE TRIGGER before_update_part BEFORE INSERT OR UPDATE ON resource
    FOR EACH ROW EXECUTE PROCEDURE before_update_part();

CREATE FUNCTION after_update_part() RETURNS TRIGGER AS $$
    BEGIN
        IF TG_OP = 'INSERT' THEN
            IF NEW.part_of IS NULL THEN
                RETURN NEW;
            END IF;
        ELSIF TG_OP = 'UPDATE' THEN
            IF (NEW.part_of IS NULL AND OLD.part_of IS NULL) OR
                ((NEW.part_of = OLD.part_of) AND (NEW.part_of_subproperty = OLD.part_of_subproperty))
            THEN
                -- part_of is unchanged, do nothing
                RETURN NEW;
            END IF;
        END IF;

        IF TG_OP != 'INSERT' THEN
            IF OLD.part_of IS NOT NULL THEN
                -- clean up links generated for old part_of
                DELETE FROM part
                    WHERE id IN (
                        -- for old resource...
                        SELECT OLD.id
                        UNION
                        --...and all its parts, ...
                        SELECT id FROM part WHERE part_of = OLD.id)
                    AND part_of IN (
                        -- ...remove links to all parents of old resource
                        SELECT part_of FROM part WHERE id = OLD.id)
                    AND part_of_subproperty = OLD.part_of_subproperty;
            END IF;
        END IF;

        IF TG_OP != 'DELETE' THEN
            IF NEW.part_of IS NOT NULL THEN
                -- generate links to the parent and grand-parents of new resource
                INSERT INTO part (id, part_of, part_of_subproperty, distance)
                    SELECT NEW.id, NEW.part_of, NEW.part_of_subproperty, 1
                    UNION
                    SELECT NEW.id, part_of, NEW.part_of_subproperty, distance + 1
                        FROM part
                        WHERE id = NEW.part_of
                        AND part_of_subproperty = NEW.part_of_subproperty;

                -- generate links from all parts of new resource to all its parents
                INSERT INTO part (id, part_of, part_of_subproperty, distance)
                    SELECT child.id, parent.part_of, NEW.part_of_subproperty,
                           child.distance + parent.distance
                        FROM part child
                        INNER JOIN part parent
                            ON parent.id = NEW.id
                            AND parent.part_of_subproperty = NEW.part_of_subproperty
                        WHERE child.part_of = NEW.id
                        AND child.part_of_subproperty = NEW.part_of_subproperty;
            END IF;
        END IF;

        -- check if subtag link was affected
        IF TG_OP != 'DELETE' THEN
            PERFORM update_nrelated_if_subtag(NEW.id, NEW.part_of_subproperty);
        END IF;
        IF TG_OP != 'INSERT' THEN
            PERFORM update_nrelated_if_subtag(OLD.id, OLD.part_of_subproperty);
        END IF;

        RETURN NEW;
    END;
$$ LANGUAGE 'plpgsql';

CREATE TRIGGER after_update_part AFTER INSERT OR UPDATE OR DELETE ON resource
    FOR EACH ROW EXECUTE PROCEDURE after_update_part();

-- update data

UPDATE resource
        SET label = 'http://www.nongnu.org/samizdat/rdf/tag#Translation'
        WHERE literal = 'false' AND uriref = 'true'
        AND label = 'http://www.nongnu.org/samizdat/rdf/focus#Translation';

CREATE FUNCTION upgrade() RETURNS VOID AS $$
    DECLARE
        version_of resource.label%TYPE := 'http://purl.org/dc/terms/isVersionOf';
        version_of_id resource.id%TYPE;
        dc_relation resource.label%TYPE := 'http://purl.org/dc/elements/1.1/relation';
        translation resource.label%TYPE := 'http://www.nongnu.org/samizdat/rdf/tag#Translation';
        translation_of resource.label%TYPE := 'http://www.nongnu.org/samizdat/rdf/schema#isTranslationOf';
        translation_of_id resource.id%TYPE;
        in_reply_to resource.label%TYPE := 'http://www.nongnu.org/samizdat/rdf/schema#inReplyTo';
        in_reply_to_id resource.id%TYPE;
        t resource.id%TYPE;
    BEGIN
        -- transform isVersionOf into subproperty of isPartOf
        SELECT id INTO version_of_id FROM resource
            WHERE label = 'false' AND uriref = 'true' AND label = version_of;
        IF NOT FOUND THEN
            INSERT INTO resource (uriref, label) VALUES ('true', version_of)
                RETURNING id INTO version_of_id;
        END IF;

        UPDATE resource r
            SET part_of = m.version_of, part_of_subproperty = version_of_id
            FROM message m
            WHERE r.part_of IS NULL
            AND m.id = r.id
            AND m.version_of IS NOT NULL;

        -- transform (reply dc::relation tag::Translation) into subproperty of isPartOf
        SELECT id INTO translation_of_id FROM resource
            WHERE label = 'false' AND uriref = 'true' AND label = translation_of;
        IF NOT FOUND THEN
            INSERT INTO resource (uriref, label) VALUES ('true', translation_of)
                RETURNING id INTO translation_of_id;
        END IF;

        UPDATE resource r
            SET part_of = m.parent, part_of_subproperty = translation_of_id
            FROM message m, statement s, resource p, resource tr
            WHERE r.part_of IS NULL
            AND m.id = r.id
            AND m.parent IS NOT NULL
            AND s.subject = m.id
            AND s.predicate = p.id AND p.label = dc_relation
            AND s.object = tr.id AND tr.label = translation;

        UPDATE vote v
            SET rating = -2
            FROM resource tr, statement s
            WHERE v.proposition = s.id AND s.object = tr.id AND tr.label = translation;

        -- transform inReplyTo into subproperty of isPartOf
        SELECT id INTO in_reply_to_id FROM resource
            WHERE label = 'false' AND uriref = 'true' AND label = in_reply_to;
        IF NOT FOUND THEN
            INSERT INTO resource (uriref, label) VALUES ('true', in_reply_to)
                RETURNING id INTO in_reply_to_id;
        END IF;

        UPDATE resource r
            SET part_of = m.parent, part_of_subproperty = in_reply_to_id
            FROM message m
            WHERE r.part_of IS NULL
            AND m.id = r.id
            AND m.parent IS NOT NULL;

        -- calculate nrelated for all tags
        FOR t IN (
            SELECT DISTINCT s.object
                FROM statement s, resource p
                WHERE s.rating > 0
                AND s.predicate = p.id AND p.label = dc_relation)
        LOOP
            PERFORM update_nrelated(t);
        END LOOP;
    END;
$$ LANGUAGE 'plpgsql';

SELECT upgrade();

DROP FUNCTION upgrade();

ALTER TABLE message DROP COLUMN parent;
ALTER TABLE message DROP COLUMN description;
ALTER TABLE message DROP COLUMN version_of;

UPDATE Resource SET label = 'member' WHERE label = 'Member';
UPDATE Resource SET label = 'message' WHERE label = 'Message';
UPDATE Resource SET label = 'statement' WHERE label = 'Statement';
UPDATE Resource SET label = 'vote' WHERE label = 'Vote';

DROP TABLE item;
DROP TABLE possession;

COMMIT;
