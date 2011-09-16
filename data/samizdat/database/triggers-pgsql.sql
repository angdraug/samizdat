-- Samizdat Database Triggers - PostgreSQL
--
--   Copyright (c) 2002-2009  Dmitry Borodaenko <angdraug@debian.org>
--
--   This program is free software.
--   You can distribute/modify this program under the terms of
--   the GNU General Public License version 3 or later.
--

CREATE FUNCTION insert_resource() RETURNS TRIGGER AS $$
    BEGIN
        IF NEW.id IS NULL THEN
            INSERT INTO Resource (literal, uriref, label)
                VALUES ('false', 'false', TG_ARGV[0]);
            NEW.id := currval('Resource_id_seq');
        END IF;
        RETURN NEW;
    END;
$$ LANGUAGE 'plpgsql';

CREATE TRIGGER insert_statement BEFORE INSERT ON Statement
    FOR EACH ROW EXECUTE PROCEDURE insert_resource('Statement');

CREATE TRIGGER insert_member BEFORE INSERT ON Member
    FOR EACH ROW EXECUTE PROCEDURE insert_resource('Member');

CREATE TRIGGER insert_message BEFORE INSERT ON Message
    FOR EACH ROW EXECUTE PROCEDURE insert_resource('Message');

CREATE TRIGGER insert_vote BEFORE INSERT ON Vote
    FOR EACH ROW EXECUTE PROCEDURE insert_resource('Vote');

CREATE TRIGGER insert_item BEFORE INSERT ON Item
    FOR EACH ROW EXECUTE PROCEDURE insert_resource('Item');

CREATE TRIGGER insert_possession BEFORE INSERT ON Possession
    FOR EACH ROW EXECUTE PROCEDURE insert_resource('Possession');

CREATE TRIGGER insert_event BEFORE INSERT ON Event
    FOR EACH ROW EXECUTE PROCEDURE insert_resource('Event');

CREATE TRIGGER insert_recurrence BEFORE INSERT ON Recurrence
    FOR EACH ROW EXECUTE PROCEDURE insert_resource('Recurrence');

CREATE FUNCTION delete_resource() RETURNS TRIGGER AS $$
    BEGIN
        DELETE FROM Resource WHERE id = OLD.id;
        RETURN NULL;
    END;
$$ LANGUAGE 'plpgsql';

CREATE TRIGGER delete_statement AFTER DELETE ON Statement
    FOR EACH ROW EXECUTE PROCEDURE delete_resource();

CREATE TRIGGER delete_member AFTER DELETE ON Member
    FOR EACH ROW EXECUTE PROCEDURE delete_resource();

CREATE TRIGGER delete_message AFTER DELETE ON Message
    FOR EACH ROW EXECUTE PROCEDURE delete_resource();

CREATE TRIGGER delete_vote AFTER DELETE ON Vote
    FOR EACH ROW EXECUTE PROCEDURE delete_resource();

CREATE TRIGGER delete_item AFTER DELETE ON Item
    FOR EACH ROW EXECUTE PROCEDURE delete_resource();

CREATE TRIGGER delete_possession AFTER DELETE ON Possession
    FOR EACH ROW EXECUTE PROCEDURE delete_resource();

CREATE TRIGGER delete_event AFTER DELETE ON Event
    FOR EACH ROW EXECUTE PROCEDURE delete_resource();

CREATE TRIGGER delete_recurrence AFTER DELETE ON Recurrence
    FOR EACH ROW EXECUTE PROCEDURE delete_resource();

CREATE FUNCTION select_subproperty(value Resource.id%TYPE, subproperty Resource.id%TYPE) RETURNS Resource.id%TYPE AS $$
    BEGIN
        IF subproperty IS NULL THEN
            RETURN NULL;
        ELSE
            RETURN value;
        END IF;
    END;
$$ LANGUAGE 'plpgsql';

CREATE FUNCTION calculate_statement_rating(statement_id Statement.id%TYPE) RETURNS Statement.rating%TYPE AS $$
    BEGIN
        RETURN (SELECT AVG(rating) FROM Vote WHERE proposition = statement_id);
    END;
$$ LANGUAGE 'plpgsql';

CREATE FUNCTION update_nrelated(tag_id Resource.id%TYPE) RETURNS VOID AS $$
    DECLARE
        dc_relation Resource.label%TYPE := 'http://purl.org/dc/elements/1.1/relation';
        s_subtag_of Resource.label%TYPE := 'http://www.nongnu.org/samizdat/rdf/schema#subTagOf';
        s_subtag_of_id Resource.id%TYPE;
        n Tag.nrelated%TYPE;
        supertag RECORD;
    BEGIN
        -- update nrelated
        SELECT COUNT(*) INTO n
            FROM Statement s
            INNER JOIN Resource p ON s.predicate = p.id
            WHERE p.label = dc_relation AND s.object = tag_id AND s.rating > 0;

        UPDATE Tag SET nrelated = n WHERE id = tag_id;
        IF NOT FOUND THEN
            INSERT INTO Tag (id, nrelated) VALUES (tag_id, n);
        END IF;

        -- update nrelated_with_subtags for this tag and its supertags
        SELECT id INTO s_subtag_of_id FROM Resource
            WHERE label = s_subtag_of;

        FOR supertag IN (
            SELECT tag_id AS id, 0 AS distance
                UNION
                SELECT part_of AS id, distance FROM Part
                    WHERE id = tag_id
                    AND part_of_subproperty = s_subtag_of_id
                ORDER BY distance ASC)
        LOOP
            UPDATE Tag
                SET nrelated_with_subtags = nrelated + COALESCE((
                    SELECT SUM(subt.nrelated)
                        FROM Part p
                        INNER JOIN Tag subt ON subt.id = p.id
                        WHERE p.part_of = supertag.id
                        AND p.part_of_subproperty = s_subtag_of_id), 0)
                WHERE id = supertag.id;
        END LOOP;
    END;
$$ LANGUAGE 'plpgsql';

CREATE FUNCTION update_nrelated_if_subtag(tag_id Resource.id%TYPE, property Resource.id%TYPE) RETURNS VOID AS $$
    DECLARE
        s_subtag_of Resource.label%TYPE := 'http://www.nongnu.org/samizdat/rdf/schema#subTagOf';
        s_subtag_of_id Resource.id%TYPE;
    BEGIN
        SELECT id INTO s_subtag_of_id FROM Resource
            WHERE label = s_subtag_of;

        IF property = s_subtag_of_id THEN
            PERFORM update_nrelated(tag_id);
        END IF;
    END;
$$ LANGUAGE 'plpgsql';

CREATE FUNCTION update_rating() RETURNS TRIGGER AS $$
    DECLARE
        dc_relation Resource.label%TYPE := 'http://purl.org/dc/elements/1.1/relation';
        old_rating Statement.rating%TYPE;
        new_rating Statement.rating%TYPE;
        tag_id Resource.id%TYPE;
        predicate_uriref Resource.label%TYPE;
    BEGIN
        -- save some values for later reference
        SELECT s.rating, s.object, p.label
            INTO old_rating, tag_id, predicate_uriref
            FROM Statement s
            INNER JOIN Resource p ON s.predicate = p.id
            WHERE s.id = NEW.proposition;

        -- set new rating of the proposition
        new_rating := calculate_statement_rating(NEW.proposition);
        UPDATE Statement SET rating = new_rating WHERE id = NEW.proposition;

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

CREATE TRIGGER update_rating AFTER INSERT OR UPDATE OR DELETE ON Vote
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
            SELECT id FROM Part WHERE part_of = NEW.id)
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

CREATE TRIGGER before_update_part BEFORE INSERT OR UPDATE ON Resource
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
                DELETE FROM Part
                    WHERE id IN (
                        -- for old resource...
                        SELECT OLD.id
                        UNION
                        --...and all its parts, ...
                        SELECT id FROM Part WHERE part_of = OLD.id)
                    AND part_of IN (
                        -- ...remove links to all parents of old resource
                        SELECT part_of FROM Part WHERE id = OLD.id)
                    AND part_of_subproperty = OLD.part_of_subproperty;
            END IF;
        END IF;

        IF TG_OP != 'DELETE' THEN
            IF NEW.part_of IS NOT NULL THEN
                -- generate links to the parent and grand-parents of new resource
                INSERT INTO Part (id, part_of, part_of_subproperty, distance)
                    SELECT NEW.id, NEW.part_of, NEW.part_of_subproperty, 1
                    UNION
                    SELECT NEW.id, part_of, NEW.part_of_subproperty, distance + 1
                        FROM Part
                        WHERE id = NEW.part_of
                        AND part_of_subproperty = NEW.part_of_subproperty;

                -- generate links from all parts of new resource to all its parents
                INSERT INTO Part (id, part_of, part_of_subproperty, distance)
                    SELECT child.id, parent.part_of, NEW.part_of_subproperty,
                           child.distance + parent.distance
                        FROM Part child
                        INNER JOIN Part parent
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

CREATE TRIGGER after_update_part AFTER INSERT OR UPDATE OR DELETE ON Resource
    FOR EACH ROW EXECUTE PROCEDURE after_update_part();
