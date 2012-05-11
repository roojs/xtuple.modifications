CREATE OR REPLACE FUNCTION invsell_apply(integer, integer) RETURNS integer
AS $BODY$
DECLARE
    i_invhist_parent_id ALIAS FOR $1;
    i_invhist_id ALIAS FOR $2;

    invsell_rec RECORD;
    
    v_totalcost_delta numeric(12, 2);
    
    v_invhist_ordnumber text;
    v_invhist_docnumber text;
    
    v_cohead_cust_id integer;
    v_cogs_accnt_id integer;
    
    v_asset_accnt_id integer;
    
    v_costcat_asset_accnt_id integer;
    v_costcat_shipasset_accnt_id integer;
    
BEGIN
    SELECT invhist_ordnumber, invhist_docnumber 
            INTO v_invhist_ordnumber, v_invhist_docnumber
            FROM invhist
            WHERE invhist_id = i_invhist_id;
    
    SELECT * INTO invsell_rec
            FROM invsell
            WHERE invsell_invhist_id = i_invhist_parent_id;
    
    
    v_totalcost_delta := invsell_rec.invsell_calc_totalcost - invsell_rec.invsell_current_totalcost;
    
    UPDATE invhist SET
        invhist_unitcost = invsell_rec.invsell_calc_unitcost,
        invhist_value_after = invhist_value_before + invhist_qty * invhist_unitcost
    WHERE 
        invhist_id >= i_invhist_id
        AND
        invhist_itemsite_id = invsell_rec.invsell_itemsite_id;
    
    SELECT cohead_cust_id
        INTO v_cohead_cust_id
        FROM cohead 
        WHERE cohead_number = CASE strpos(v_invhist_ordnumber, '-')
                        WHEN 0 THEN v_invhist_ordnumber 
                        ELSE substr(v_invhist_ordnumber, 1, strpos(v_invhist_ordnumber, '-') - 1)
                    END;
    
    v_cogs_accnt_id = resolvecosaccount(invsell_rec.invsell_itemsite_id, v_cohead_cust_id);
    
    SELECT costcat_asset_accnt_id, costcat_shipasset_accnt_id
        INTO v_costcat_asset_accnt_id, v_costcat_shipasset_accnt_id
        FROM costcat, itemsite
        WHERE 
            costcat_id = itemsite_costcat 
            AND 
            itemsite_id = invsell_rec.invsell_itemsite_id;
    
    UPDATE gltrans SET
        gltrans_ammount = invsell_rec.invsell_calc_unitcost * invsell_rec.invsell_qty
    WHERE 
        (
            (
                gltrans_doctype = 'SO'
                AND
                gltrans_source = 'S/R'
            )
            OR
            (
                gltrans_doctype = 'IN'
                AND
                gltrans_source = 'S/O'
            )
        )
        AND 
        gltrans_misc_id = i_invhist_id
        AND
        gltrans_accnt_id in (v_costcat_shipasset_accnt_id, v_cogs_accnt_id);
        
    UPDATE gltrans SET
        gltrans_ammount = - invsell_rec.invsell_calc_unitcost * invsell_rec.invsell_qty
    WHERE 
        (
            (
                gltrans_doctype = 'SO'
                AND
                gltrans_source = 'S/R'
            )
            OR
            (
                gltrans_doctype = 'IN'
                AND
                gltrans_source = 'S/O'
            )
        )
        AND 
        gltrans_misc_id = i_invhist_id
        AND
        gltrans_accnt_id = v_costcat_asset_accnt_id;
        
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
  
ALTER FUNCTION  invsell_apply(integer, integer)
  OWNER TO admin;
