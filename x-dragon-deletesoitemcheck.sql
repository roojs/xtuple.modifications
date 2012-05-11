-- part of the changes for non-destructive kit parts explode

-- Function: deletesoitem(integer)

-- DROP FUNCTION deletesoitem(integer);

CREATE OR REPLACE FUNCTION deletesoitemcheck(integer)
  RETURNS integer AS
$BODY$
DECLARE
  pSoitemid	ALIAS FOR $1;

  _result       INTEGER;
 

BEGIN
-- Get coitem
    SELECT deletesoitem() as _result;
    
    IF (_result > -1) THEN
        RAISE EXCEPTION 'Can be done';
    END IF;
   
    RETURN _result;
 
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION deletesoitemcheck(integer)
  OWNER TO admin;
