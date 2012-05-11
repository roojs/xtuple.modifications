CREATE OR REPLACE FUNCTION invsell_apply_order(integer) RETURNS integer
AS $BODY$
DECLARE
    i_invsell_invhist_id ALIAS FOR $1;

    invsell_rec RECORD;
    
    v_totalcost_delta numeric(12, 2);
    
    v_invhist_ordnumber text;
    
BEGIN

    SELECT * INTO invsell_rec
            FROM invsell
            WHERE invsell_invhist_id = i_invsell_invhist_id;
    
    v_totalcost_delta := invsell_rec.invsell_calc_totalcost - invsell_rec.invsell_current_totalcost;

        
    UPDATE itemsite 
                SET 
                itemsite_value = invsell_rec.invsell_totalcost_before + invsell_rec.invsell_calc_totalcost
            WHERE
                 itemsite_id = invsell_rec.invsell_itemsite_id;
    
    UPDATE coitem
                SET
                coitem_unitprice = invsell_rec.invsell_calc_unitcost
            FROM cohead
            WHERE 
                coitem_cohead_id = cohead_id
                AND
                cohead_number || '.' || coitem_linenumber = invsell_rec.invsell_ordnumber;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
  
ALTER FUNCTION  invsell_apply_order(integer)
  OWNER TO admin;
