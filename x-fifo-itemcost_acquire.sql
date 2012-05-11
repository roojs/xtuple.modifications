CREATE OR REPLACE FUNCTION itemcost_acquire (integer, numeric(16, 6)) RETURNS numeric(16, 6)
AS $BODY$
DECLARE
  -- Variable naming :  i_ = INPUT,  v_ = Variables
  i_itemsite_id         ALIAS FOR $1;
  i_unitcost             ALIAS FOR $2;
  
BEGIN 

    -- if FIFO method not used 
    IF ( v_itemsite_costmethod <> 'F' AND !fetchMetricBool('UseStandardAsFIFO') ) THEN
        RETURN stdcost(i_itemsite_id);
    END IF;
    
    RETURN i_unitcost;
    
END
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
  
ALTER FUNCTION  itemcost_acquire(integer, numeric(16, 6))
  OWNER TO admin;
