-- //
-- //  autosqlconf.postgres.sql
-- //  zero-framework postgres autosqlconf script
-- //
-- //  Created by Zero on 2020/11/11.
-- //  Copyright © 2020年 RyeWhiskey. All rights reserved.
-- //

-- // INIT POSTGRES AUTOSQLCONF DML BEGIN 

DROP FUNCTION IF EXISTS COLUMN_EXISTS;
CREATE FUNCTION  COLUMN_EXISTS (
	C_TABLE_SCHEMA VARCHAR(32),
	C_TABLE_NAME VARCHAR(64),
	C_COLUMN_NAME VARCHAR(64)
) RETURNS INTEGER AS
$$ 
DECLARE s INTEGER;
BEGIN
	SELECT 
		count(1) INTO s
	FROM 
		INFORMATION_SCHEMA.COLUMNS
	WHERE
		TABLE_CATALOG = lower(C_TABLE_SCHEMA) 
	AND
	    TABLE_NAME = lower(C_TABLE_NAME)
	AND
	    COLUMN_NAME = lower(C_COLUMN_NAME);
	RETURN s;
END 
$$
LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS COLUMN_DIFF; 
CREATE FUNCTION COLUMN_DIFF (
	C_TABLE_SCHEMA VARCHAR(32),
	C_TABLE_NAME VARCHAR(64),
	C_COLUMN_NAME VARCHAR(64),
	C_IS_NULLABLE VARCHAR(8),
	C_COLUMN_TYPE VARCHAR(16),
	C_COLUMN_DEFAULT VARCHAR(64)
) RETURNS INTEGER AS
$$
DECLARE s INTEGER;
BEGIN
	IF C_COLUMN_DEFAULT IS NULL
    THEN 
    	SELECT 
			count(1) INTO s
		FROM 
			INFORMATION_SCHEMA.COLUMNS
		WHERE
			TABLE_CATALOG = lower(C_TABLE_SCHEMA)
		AND
		    TABLE_NAME = lower(C_TABLE_NAME)
		AND
			COLUMN_NAME = lower(C_COLUMN_NAME)
		AND
		    IS_NULLABLE = C_IS_NULLABLE
		AND
			strpos(lower(C_COLUMN_TYPE), UDT_NAME) = 1
		AND
			(character_maximum_length IS NULL OR strpos(lower(C_COLUMN_TYPE), '('||character_maximum_length||')') > 0)
		AND
			COLUMN_DEFAULT IS NULL;
    ELSE
    	SELECT 
			count(1) INTO s
		FROM 
			INFORMATION_SCHEMA.COLUMNS
		WHERE
			TABLE_CATALOG = lower(C_TABLE_SCHEMA)
		AND
		    TABLE_NAME = lower(C_TABLE_NAME)
		AND
			COLUMN_NAME = lower(C_COLUMN_NAME)
		AND
		    IS_NULLABLE = C_IS_NULLABLE
		AND
			strpos(lower(C_COLUMN_TYPE), UDT_NAME) = 1
		AND
			(character_maximum_length IS NULL OR strpos(lower(C_COLUMN_TYPE), '('||character_maximum_length||')') > 0)
		AND
			COLUMN_DEFAULT = C_COLUMN_DEFAULT;
    END IF;
	RETURN s;
END 
$$
LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS DML_COLUMN;
CREATE FUNCTION DML_COLUMN (
	IN C_TABLE_SCHEMA VARCHAR(32),
	IN C_TABLE_NAME VARCHAR(64),
	IN C_COLUMN_NAME VARCHAR(64),
	IN C_IS_NULLABLE VARCHAR(8),
	IN C_COLUMN_TYPE VARCHAR(16),
	IN C_COLUMN_DEFAULT VARCHAR(64)
) RETURNS "pg_catalog"."void" AS 
$$
DECLARE C_EXISTS INTEGER;
DECLARE C_DIFF INTEGER;
DECLARE DML_SQL TEXT;
DECLARE DML_IS_NULLABLE TEXT;
BEGIN
	SELECT COLUMN_EXISTS(C_TABLE_SCHEMA, C_TABLE_NAME, C_COLUMN_NAME) INTO C_EXISTS;
	SELECT COLUMN_DIFF(C_TABLE_SCHEMA, C_TABLE_NAME, C_COLUMN_NAME,  C_IS_NULLABLE, C_COLUMN_TYPE, C_COLUMN_DEFAULT) INTO C_DIFF;
	DML_SQL := 'ALTER TABLE ';
	DML_IS_NULLABLE := ' NOT NULL ';
	IF C_IS_NULLABLE = 'YES'
	THEN
		DML_IS_NULLABLE := ' NULL ';
	END IF;

	IF C_EXISTS = 0
	THEN
		DML_SQL := DML_SQL||' '||C_TABLE_NAME||' ADD COLUMN '||C_COLUMN_NAME||' '||C_COLUMN_TYPE||' '||DML_IS_NULLABLE;
		IF C_COLUMN_DEFAULT IS NOT NULL
		THEN
			DML_SQL := DML_SQL||' DEFAULT '||C_COLUMN_DEFAULT;
		END IF;
	    EXECUTE DML_SQL;
	ELSEIF C_DIFF = 0
	THEN
	   	EXECUTE DML_SQL||' '||C_TABLE_NAME||' ALTER COLUMN '||C_COLUMN_NAME||' TYPE '||C_COLUMN_TYPE;
		EXECUTE DML_SQL||' '||C_TABLE_NAME||' ALTER COLUMN '||C_COLUMN_NAME||' SET '||DML_IS_NULLABLE;
		IF C_COLUMN_DEFAULT IS NOT NULL
		THEN
			EXECUTE DML_SQL||' '||C_TABLE_NAME||' ALTER COLUMN '||C_COLUMN_NAME||' SET DEFAULT '||C_COLUMN_DEFAULT;
		ELSE
			EXECUTE DML_SQL||' '||C_TABLE_NAME||' ALTER COLUMN '||C_COLUMN_NAME||' DROP DEFAULT ';
		END IF;
	END IF;
END 
$$
LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS DROP_COLUMN;
CREATE FUNCTION DROP_COLUMN (
	IN C_TABLE_SCHEMA VARCHAR(32),
	IN C_TABLE_NAME VARCHAR(64),
	IN C_COLUMN_NAME VARCHAR(64)
) RETURNS "pg_catalog"."void" AS 
$$
DECLARE C_EXISTS INTEGER;
BEGIN
	SELECT COLUMN_EXISTS(C_TABLE_SCHEMA, C_TABLE_NAME, C_COLUMN_NAME) INTO C_EXISTS;
	IF C_EXISTS > 0
	THEN
		EXECUTE 'ALTER TABLE '||C_TABLE_NAME||' DROP COLUMN '||C_COLUMN_NAME;
	END IF;
END 
$$
LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS INDEX_EXISTS;
CREATE FUNCTION  INDEX_EXISTS (
	C_TABLE_SCHEMA VARCHAR(32),
	C_TABLE_NAME VARCHAR(64),
	C_INDEX_NAME VARCHAR(64)
) RETURNS INTEGER AS 
$$
DECLARE s INTEGER;
BEGIN
	SELECT 
		count(1) INTO s
	FROM 
		pg_indexes
	WHERE
		TABLENAME = lower(C_TABLE_NAME)
	AND
	    INDEXNAME = lower(C_INDEX_NAME);

	IF s = 0
	THEN
		SELECT 
			count(1) INTO s
		FROM 
			pg_constraint
		WHERE
		    CONNAME = lower(C_INDEX_NAME)
		AND
			CONTYPE = 'f';
	END IF;
	RETURN s;
END
$$
LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS DML_CONSTRAINT;
CREATE FUNCTION DML_CONSTRAINT(
	IN C_TABLE_SCHEMA VARCHAR(32),
	IN C_TABLE_NAME VARCHAR(64),
	IN C_INDEX_NAME VARCHAR(64),
	IN C_DEFINE_INDEX_SQL VARCHAR(256)
) RETURNS "pg_catalog"."void" AS 
$$
DECLARE C_EXISTS INTEGER;
BEGIN
	SELECT INDEX_EXISTS(C_TABLE_SCHEMA, C_TABLE_NAME, C_INDEX_NAME) INTO C_EXISTS;
	IF C_EXISTS = 0
	THEN
			EXECUTE 'ALTER TABLE '||C_TABLE_NAME||' ADD CONSTRAINT '||C_INDEX_NAME||' '||C_DEFINE_INDEX_SQL;
	END IF;
END 
$$
LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS DROP_CONSTRAINT;
CREATE FUNCTION DROP_CONSTRAINT(
	IN C_TABLE_SCHEMA VARCHAR(32),
	IN C_TABLE_NAME VARCHAR(64),
	IN C_INDEX_NAME VARCHAR(64)
) RETURNS "pg_catalog"."void" AS 
$$
DECLARE C_EXISTS INTEGER;
BEGIN
	SELECT INDEX_EXISTS(C_TABLE_SCHEMA, C_TABLE_NAME, C_INDEX_NAME) INTO C_EXISTS;
	IF C_EXISTS > 0
	THEN
		EXECUTE 'ALTER TABLE '||C_TABLE_NAME||' DROP CONSTRAINT '||C_INDEX_NAME;
	END IF;
END 
$$
LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS DML_INDEX;
CREATE FUNCTION DML_INDEX(
	IN C_TABLE_SCHEMA VARCHAR(32),
	IN C_TABLE_NAME VARCHAR(64),
	IN C_COLUMN_NAME VARCHAR(64)
) RETURNS "pg_catalog"."void" AS 
$$
DECLARE C_EXISTS INTEGER;
BEGIN
	SELECT INDEX_EXISTS(C_TABLE_SCHEMA, C_TABLE_NAME, lower('idx_'||C_TABLE_NAME||'_'||C_COLUMN_NAME)) INTO C_EXISTS;
	IF C_EXISTS = 0
	THEN
		EXECUTE 'CREATE INDEX '||lower('idx_'||C_TABLE_NAME||'_'||C_COLUMN_NAME)||' ON '||C_TABLE_NAME||'('||C_COLUMN_NAME||')';
	END IF;
END 
$$
LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS DROP_INDEX;
CREATE FUNCTION DROP_INDEX(
	IN C_TABLE_SCHEMA VARCHAR(32),
	IN C_TABLE_NAME VARCHAR(64),
	IN C_COLUMN_NAME VARCHAR(64)
) RETURNS "pg_catalog"."void" AS 
$$
DECLARE C_EXISTS INTEGER;
BEGIN
	SELECT INDEX_EXISTS(C_TABLE_SCHEMA, C_TABLE_NAME, lower('idx_'||C_TABLE_NAME||'_'||C_COLUMN_NAME)) INTO C_EXISTS;
	IF C_EXISTS > 0
	THEN
		EXECUTE 'DROP INDEX '||lower('idx_'||C_TABLE_NAME||'_'||C_COLUMN_NAME);
	END IF;
END 
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION  update_timestamp() RETURNS TRIGGER AS
$$
BEGIN
    new.UPDATE_TIME = current_timestamp;
    return new;
END
$$
LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS TRIGGER_EXISTS;
CREATE FUNCTION TRIGGER_EXISTS(
	IN C_TABLE_SCHEMA VARCHAR(32),
	IN C_TABLE_NAME VARCHAR(64),
	IN C_TRIGGER_TIMING VARCHAR(16),
	IN C_TRIGGER_EVENT VARCHAR(16),
	IN C_TRIGGER_NAME VARCHAR(64),
	IN C_TRIGGER_ACTION TEXT
) RETURNS INTEGER AS 
$$
DECLARE s INTEGER;
BEGIN
	SELECT 
		count(1) INTO s
	FROM 
		INFORMATION_SCHEMA.TRIGGERS
	WHERE
		TRIGGER_CATALOG = lower(C_TABLE_SCHEMA) 
	AND
	    EVENT_OBJECT_TABLE = lower(C_TABLE_NAME)
	AND
	    ACTION_TIMING = upper(C_TRIGGER_TIMING)
	AND
	    EVENT_MANIPULATION = upper(C_TRIGGER_EVENT)
	AND
		ACTION_STATEMENT = C_TRIGGER_ACTION;
	RETURN s;
END 
$$
LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS DML_TRIGGER;
CREATE FUNCTION DML_TRIGGER(
	IN C_TABLE_SCHEMA VARCHAR(32),
	IN C_TABLE_NAME VARCHAR(64),
	IN C_TRIGGER_TIMING VARCHAR(16),
	IN C_TRIGGER_EVENT VARCHAR(16),
	IN C_TRIGGER_NAME VARCHAR(64),
	IN C_TRIGGER_ACTION TEXT
) RETURNS "pg_catalog"."void" AS 
$$
DECLARE C_EXISTS INTEGER;
BEGIN
	SELECT TRIGGER_EXISTS(C_TABLE_SCHEMA, C_TABLE_NAME, C_TRIGGER_TIMING, C_TRIGGER_EVENT, C_TRIGGER_NAME, C_TRIGGER_ACTION) INTO C_EXISTS;
	IF C_EXISTS = 0
	THEN
		EXECUTE 'CREATE OR REPLACE TRIGGER '||C_TRIGGER_NAME||' '||C_TRIGGER_TIMING||' '||C_TRIGGER_EVENT||' ON '||C_TABLE_NAME||' FOR EACH ROW '||C_TRIGGER_ACTION;
	END IF;
END 
$$
LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS DROP_TRIGGER;
CREATE FUNCTION DROP_TRIGGER(
	IN C_TABLE_SCHEMA VARCHAR(32),
	IN C_TABLE_NAME VARCHAR(64),
	IN C_TRIGGER_NAME VARCHAR(64)
) RETURNS "pg_catalog"."void" AS 
$$
BEGIN
	EXECUTE 'DROP TRIGGER IF EXISTS '||C_TRIGGER_NAME||' ON '||C_TABLE_NAME;
END 
$$
LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS DML_PRIMARY;
CREATE FUNCTION DML_PRIMARY(
	IN C_TABLE_SCHEMA VARCHAR(32),
	IN C_TABLE_NAME VARCHAR(64),
	IN C_COLUMN_NAME VARCHAR(64)
) RETURNS "pg_catalog"."void" AS 
$$
BEGIN
	PERFORM DML_CONSTRAINT(C_TABLE_SCHEMA, C_TABLE_NAME, 'pk_'||C_TABLE_NAME||'_'||C_COLUMN_NAME, 'PRIMARY KEY('||C_COLUMN_NAME||')');
END 
$$
LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS DROP_PRIMARY;
CREATE FUNCTION DROP_PRIMARY(
	IN C_TABLE_SCHEMA VARCHAR(32),
	IN C_TABLE_NAME VARCHAR(64),
	IN C_COLUMN_NAME VARCHAR(64)
) RETURNS "pg_catalog"."void" AS 
$$
BEGIN
	PERFORM DROP_CONSTRAINT(C_TABLE_SCHEMA, C_TABLE_NAME, 'pk_'||C_TABLE_NAME||'_'||C_COLUMN_NAME); 
END 
$$
LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS DML_UNIQUE;
CREATE FUNCTION DML_UNIQUE(
	IN C_TABLE_SCHEMA VARCHAR(32),
	IN C_TABLE_NAME VARCHAR(64),
	IN C_COLUMN_NAME VARCHAR(64)
) RETURNS "pg_catalog"."void" AS 
$$
BEGIN
	PERFORM DML_CONSTRAINT(C_TABLE_SCHEMA, C_TABLE_NAME, 'uk_'||C_TABLE_NAME||'_'||C_COLUMN_NAME, 'UNIQUE('||C_COLUMN_NAME||')');
END 
$$
LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS DROP_UNIQUE;
CREATE FUNCTION DROP_UNIQUE(
	IN C_TABLE_SCHEMA VARCHAR(32),
	IN C_TABLE_NAME VARCHAR(64),
	IN C_COLUMN_NAME VARCHAR(64)
) RETURNS "pg_catalog"."void" AS 
$$
BEGIN
	PERFORM DROP_CONSTRAINT(C_TABLE_SCHEMA, C_TABLE_NAME, 'uk_'||C_TABLE_NAME||'_'||C_COLUMN_NAME); 
END 
$$
LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS DML_FOREIGN;
CREATE FUNCTION DML_FOREIGN(
	IN C_TABLE_SCHEMA VARCHAR(32),
	IN C_TABLE_NAME VARCHAR(64),
	IN C_COLUMN_NAME VARCHAR(64),
	IN R_TABLE_NAME VARCHAR(64),
	IN R_COLUMN_NAME VARCHAR(64)
) RETURNS "pg_catalog"."void" AS 
$$
BEGIN
	PERFORM DML_CONSTRAINT(
		C_TABLE_SCHEMA, 
		C_TABLE_NAME, 
		'fk_'||C_TABLE_NAME||'_'||C_COLUMN_NAME, 
		'FOREIGN KEY('||C_COLUMN_NAME||') 
			REFERENCES '||R_TABLE_NAME||'('||R_COLUMN_NAME||')  
			ON UPDATE CASCADE 
			ON DELETE CASCADE');
END 
$$
LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS DROP_FOREIGN;
CREATE FUNCTION DROP_FOREIGN(
	IN C_TABLE_SCHEMA VARCHAR(32),
	IN C_TABLE_NAME VARCHAR(64),
	IN C_COLUMN_NAME VARCHAR(64)
) RETURNS "pg_catalog"."void" AS 
$$
BEGIN
	PERFORM DROP_CONSTRAINT(C_TABLE_SCHEMA, C_TABLE_NAME, 'fk_'||C_TABLE_NAME||'_'||C_COLUMN_NAME); 
END 
$$
LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS TABLE_EXISTS;
CREATE FUNCTION  TABLE_EXISTS (
	C_TABLE_SCHEMA VARCHAR(32),
	C_TABLE_NAME VARCHAR(64)
) RETURNS INTEGER AS 
$$
DECLARE s INTEGER;
BEGIN
	SELECT 
		count(1) INTO s
	FROM 
		INFORMATION_SCHEMA.TABLES
	WHERE
		TABLE_CATALOG = lower(C_TABLE_SCHEMA) 
	AND
	    TABLE_NAME = lower(C_TABLE_NAME);
	RETURN s;
END
$$
LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS DML_TABLE;
CREATE FUNCTION DML_TABLE(
	IN C_TABLE_SCHEMA VARCHAR(32),
	IN C_TABLE_NAME VARCHAR(64)
) RETURNS "pg_catalog"."void" AS 
$$
DECLARE C_EXISTS INTEGER;
DECLARE DML_SQL TEXT;
BEGIN
	SELECT TABLE_EXISTS(C_TABLE_SCHEMA, C_TABLE_NAME) INTO C_EXISTS;
	IF C_EXISTS <= 0
	THEN
		DML_SQL := 'CREATE TABLE IF NOT EXISTS '||C_TABLE_NAME||' (';
		DML_SQL := DML_SQL||'id UUID NOT NULL DEFAULT uuid_generate_v4()';
		DML_SQL := DML_SQL||');';
	    EXECUTE DML_SQL;
		PERFORM DML_PRIMARY(C_TABLE_SCHEMA, C_TABLE_NAME, 'id');
	END IF;
END 
$$
LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS create_0struct;
CREATE FUNCTION create_0struct(
	IN C_TABLE_SCHEMA VARCHAR(32),
	IN C_TABLE_NAME VARCHAR(64)
) RETURNS "pg_catalog"."void" AS 
$$
BEGIN
	PERFORM DML_TABLE(C_TABLE_SCHEMA, C_TABLE_NAME),
		DML_COLUMN(C_TABLE_SCHEMA, C_TABLE_NAME, 'create_time', 'NO', 'TIMESTAMPTZ', 'CURRENT_TIMESTAMP'),
		DML_COLUMN(C_TABLE_SCHEMA, C_TABLE_NAME, 'update_time', 'NO', 'TIMESTAMPTZ', 'CURRENT_TIMESTAMP'),
		DML_COLUMN(C_TABLE_SCHEMA, C_TABLE_NAME, 'features', 'NO', 'JSONB', NULL),
		DML_INDEX(C_TABLE_SCHEMA, C_TABLE_NAME, 'create_time'),
		DML_INDEX(C_TABLE_SCHEMA, C_TABLE_NAME, 'update_time'),
		DML_TRIGGER(C_TABLE_SCHEMA, C_TABLE_NAME, 'BEFORE', 'UPDATE', C_TABLE_NAME||'_update', 'EXECUTE PROCEDURE update_timestamp()');
END 
$$
LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS create_0flagstruct;
CREATE FUNCTION create_0flagstruct(
	IN C_TABLE_SCHEMA VARCHAR(32),
	IN C_TABLE_NAME VARCHAR(64)
) RETURNS "pg_catalog"."void" AS 
$$
BEGIN
	PERFORM DML_TABLE(C_TABLE_SCHEMA, C_TABLE_NAME),
		DML_COLUMN(C_TABLE_SCHEMA, C_TABLE_NAME, 'create_time', 'NO', 'TIMESTAMPTZ', 'CURRENT_TIMESTAMP'),
		DML_COLUMN(C_TABLE_SCHEMA, C_TABLE_NAME, 'update_time', 'NO', 'TIMESTAMPTZ', 'CURRENT_TIMESTAMP'),
		DML_COLUMN(C_TABLE_SCHEMA, C_TABLE_NAME, 'flag', 'NO', 'INT', NULL),
		DML_COLUMN(C_TABLE_SCHEMA, C_TABLE_NAME, 'features', 'NO', 'JSONB', NULL),
		DML_INDEX(C_TABLE_SCHEMA, C_TABLE_NAME, 'create_time'),
		DML_INDEX(C_TABLE_SCHEMA, C_TABLE_NAME, 'update_time'),
		DML_TRIGGER(C_TABLE_SCHEMA, C_TABLE_NAME, 'BEFORE', 'UPDATE', C_TABLE_NAME||'_update', 'EXECUTE PROCEDURE update_timestamp()');
END 
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION  dispatch_0struct_partition() RETURNS TRIGGER AS
$$
DECLARE C_PART_TABLE_NAME VARCHAR(64);
DECLARE C_PART_BEGIN VARCHAR(64);
DECLARE C_PART_END VARCHAR(64);
DECLARE C_EXISTS INTEGER;
BEGIN
	C_PART_TABLE_NAME := lower(TG_TABLE_NAME||'_'||to_char(new.CREATE_TIME, 'YYYYMM'));
	SELECT 
		count(1) INTO C_EXISTS
	FROM 
		INFORMATION_SCHEMA.TABLES
	WHERE
		TABLE_NAME = C_PART_TABLE_NAME;

	IF C_EXISTS = 0
	THEN
		C_PART_BEGIN := to_char(new.CREATE_TIME, 'YYYY-MM-01');
		C_PART_END := to_char(new.CREATE_TIME + interval '1 month', 'YYYY-MM-01');

		EXECUTE 'CREATE TABLE '||C_PART_TABLE_NAME||' (LIKE zeroaikit_facemodxt INCLUDING ALL) INHERITS ('||TG_TABLE_NAME||')';
		EXECUTE 'ALTER TABLE '||C_PART_TABLE_NAME||' ADD CONSTRAINT ck_'||C_PART_TABLE_NAME||'_create_time check(create_time >= '''||C_PART_BEGIN||''' AND create_time < '''||C_PART_END||''')';
		EXECUTE 'CREATE OR REPLACE TRIGGER '||C_PART_TABLE_NAME||'_update BEFORE UPDATE ON '||C_PART_TABLE_NAME||' FOR EACH ROW EXECUTE PROCEDURE update_timestamp()';
	END IF;

	EXECUTE 'INSERT INTO '||C_PART_TABLE_NAME||' SELECT ($1).*' USING NEW;
	return NULL;
END
$$
LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS DML_0SPART;
CREATE FUNCTION DML_0SPART(
	IN C_TABLE_SCHEMA VARCHAR(32),
	IN C_TABLE_NAME VARCHAR(64)
) RETURNS "pg_catalog"."void" AS 
$$
BEGIN
	PERFORM DML_TRIGGER(C_TABLE_SCHEMA, C_TABLE_NAME, 'BEFORE', 'INSERT', C_TABLE_NAME||'_d0stp', 'EXECUTE PROCEDURE dispatch_0struct_partition()');
END 
$$
LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS DROP_PARTITION_TABLE;
CREATE FUNCTION DROP_PARTITION_TABLE(
	IN C_TABLE_SCHEMA VARCHAR(32),
	IN C_TABLE_NAME VARCHAR(64)
) RETURNS "pg_catalog"."void" AS 
$$
DECLARE C_PART_TABLE_NAME VARCHAR(128);
BEGIN
	FOR C_PART_TABLE_NAME IN 
		SELECT 
			TABLE_NAME
		FROM 
			INFORMATION_SCHEMA.TABLES
		WHERE
			TABLE_NAME LIKE lower(C_TABLE_NAME)||'_%'
	LOOP
		EXECUTE 'DROP TABLE IF EXISTS '||C_PART_TABLE_NAME;
	END LOOP;
	EXECUTE 'DROP TABLE IF EXISTS '||C_TABLE_NAME;
END 
$$
LANGUAGE plpgsql;

-- // INIT POSTGRES AUTOSQLCONF DML END 

