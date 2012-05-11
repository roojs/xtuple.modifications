

-- create an index on location so it's fast..

CREATE INDEX invdetail_location_id_idx
  ON invdetail
  USING btree
  (invdetail_location_id );

-- returns the exact quantity of stock at the invdetail_id time..


CREATE OR REPLACE FUNCTION invdetail_bydate(int)
  RETURNS  numeric(18,6)  AS
$BODY$
DECLARE
  i_id ALIAS FOR $1;
  v_itemsite_id INTEGER;
  v_location_id INTEGER;
  v_transdate timestamp with time zone;
  v_qty numeric(18,6) ;
  v_return numeric(18,6) ;
BEGIN
    v_return := 0;




   SELECT
     invhist_itemsite_id,
     invdetail_location_id,
     invhist_transdate,
     invdetail_qty
        INTO
        v_itemsite_id, 
        v_location_id ,
        v_transdate,
        v_qty
          FROM invdetail LEFT JOIN invhist ON 
            invdetail_invhist_id = invhist_id
         WHERE
            invdetail_id = i_id
          LIMIT 1;
   

-- # when transactions are the same day, we only want to include the ones with lower ids..


    SELECT   COALESCE(SUM( invdetail_qty), 0) + v_qty INTO v_return 
         FROM invdetail LEFT JOIN invhist ON 
            invdetail_invhist_id = invhist_id
        WHERE
            invdetail_location_id = v_location_id
            AND
            invhist_itemsite_id = v_itemsite_id
            AND   ( 
                invhist_transdate <  v_transdate 
                OR
                (invhist_transdate =  v_transdate AND invdetail_id < i_id)
            )  ;

    IF (v_return IS NULL) THEN 
        v_return = 0;
    END IF;


    -- UPDATE invdetail SET invdetail_bydate_qty_after = v_return WHERE invdetail_id = i_id;


  RETURN v_return;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION  invdetail_bydate(int)
  OWNER TO admin;

