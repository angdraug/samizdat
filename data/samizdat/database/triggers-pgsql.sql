-- Samizdat Database Triggers - PostgreSQL
--
--   Copyright (c) 2002-2011  Dmitry Borodaenko <angdraug@debian.org>
--
--   This program is free software.
--   You can distribute/modify this program under the terms of
--   the GNU General Public License version 3 or later.
--

CREATE FUNCTION insert_resource() RETURNS TRIGGER AS $$
    BEGIN
        IF NEW.id IS NULL THEN
            INSERT INTO resource (literal, uriref, label)
                VALUES ('false', 'false', TG_ARGV[0]);
            NEW.id := currval('resource_id_seq');
        END IF;
        RETURN NEW;
    END;
$$ LANGUAGE 'plpgsql';

CREATE TRIGGER insert_statement BEFORE INSERT ON statement
    FOR EACH ROW EXECUTE PROCEDURE insert_resource('statement');

CREATE TRIGGER insert_member BEFORE INSERT ON member
    FOR EACH ROW EXECUTE PROCEDURE insert_resource('member');

CREATE TRIGGER insert_message BEFORE INSERT ON message
    FOR EACH ROW EXECUTE PROCEDURE insert_resource('message');

CREATE TRIGGER insert_vote BEFORE INSERT ON vote
    FOR EACH ROW EXECUTE PROCEDURE insert_resource('vote');

CREATE FUNCTION delete_resource() RETURNS TRIGGER AS $$
    BEGIN
        DELETE FROM resource WHERE id = OLD.id;
        RETURN NULL;
    END;
$$ LANGUAGE 'plpgsql';

CREATE TRIGGER delete_statement AFTER DELETE ON statement
    FOR EACH ROW EXECUTE PROCEDURE delete_resource();

CREATE TRIGGER delete_member AFTER DELETE ON member
    FOR EACH ROW EXECUTE PROCEDURE delete_resource();

CREATE TRIGGER delete_message AFTER DELETE ON message
    FOR EACH ROW EXECUTE PROCEDURE delete_resource();

CREATE TRIGGER delete_vote AFTER DELETE ON vote
    FOR EACH ROW EXECUTE PROCEDURE delete_resource();

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
