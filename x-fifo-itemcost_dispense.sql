CREATE OR REPLACE FUNCTION itemcost_dispense (integer, numeric(18, 6))  RETURNS  numeric(16, 6)
AS $BODY$
DECLARE
  -- Variable naming :  i_ = INPUT,  v_ = Variables
  i_itemsite_id         ALIAS FOR $1;
  i_invsell_qty         ALIAS FOR $2;
  v_invsell_qtybefore numeric(18, 6) DEFAULT 0;
  v_invsell_totalcostbefore numeric(12, 2) DEFAULT 0;
  v_invsell_calc_totalcost numeric(12, 2) DEFAULT 0;
  
  v_invsell_qty numeric(18, 6) DEFAULT 0;
  v_itemsite_costmethod character(1);
  
  v_totalcost_avail numeric(12, 2) DEFAULT 0;
  v_qty_avail numeric(18, 6) DEFAULT 0;

  v_calc_unitcost numeric(16, 6) DEFAULT 0;
  
BEGIN 

    -- find record by invhist_id and get orders
    -- itemsite_id, qty and qtybefore

    SELECT itemsite_costmethod INTO v_itemsite_costmethod
    FROM itemsite 
    WHERE itemsite_id = i_itemsite_id;
    
    -- if FIFO method not used 
    IF ( v_itemsite_costmethod <> 'F' AND !fetchMetricBool('UseStandardAsFIFO') ) THEN
        RETURN stdcost(i_itemsite_id);
    END IF;
-- add our cost before value here..    
    SELECT 
            invsell_qtybefore, invsell_totalcostbefore, 
            invsell_qty, invsell_calc_totalcost
            
    FROM invsell 
    INTO 
            v_invsell_qtybefore, v_invsell_totalcostbefore, 
            v_invsell_qty, v_invsell_calc_totalcost
    WHERE 
        invsell_itemsite_id = i_itemsite_id
        AND
        invsell_estimated = false
    ORDER BY invsell_qtybefore DESC
    LIMIT 1;

    
    v_invsell_qtybefore = v_invsell_qtybefore + v_invsell_qty;
    v_invsell_totalcostbefore = v_invsell_totalcostbefore + v_invsell_calc_totalcost;
    
    SELECT 
        -- we take all the stock
        SUM(invbuy_totalcost)
        
        -- we take leftovers
        - (v_invsell_totalcostbefore - min(invbuy_totalcostafter-invbuy_totalcost)) 

        -- we take upto how many we need
        - (max(invbuy_qtyafter)-v_invsell_qtybefore-i_invsell_qty)
            *(max(invbuy_totalcostafter) - max(invbuy_totalcostafter-invbuy_totalcost))/(max(invbuy_qtyafter) - max(invbuy_qtyafter-invbuy_qty)) totalcost,

        SUM(invbuy_qty)
        
        - (v_invsell_qtybefore - min(invbuy_qtyafter - invbuy_qty))
        
        - (max(invbuy_qtyafter)-v_invsell_qtybefore-i_invsell_qty) qty
        
        FROM invbuy 
        INTO v_totalcost_avail, v_qty_avail
            WHERE
                invbuy_itemsite_id = i_itemsite_id
                AND
                invbuy_qtyafter > v_invsell_qtybefore
                AND
                invbuy_qtyafter - invbuy_qty < v_invsell_qtybefore + i_invsell_qty;

    
    -- if not found inventory for sell
    if (NOT FOUND OR v_qty_avail < 0) THEN
        -- check case when buy transaction exist 
        -- but its quantity greater than sell quantity
        -- i.e invbuy_qty > invsell_qty
        SELECT invbuy_unitcost
        FROM invbuy INTO v_calc_unitcost
                WHERE
                    invbuy_itemsite_id = i_itemsite_id
                    AND
                    invbuy_qtyafter > v_invsell_qtybefore + i_invsell_qty
                
                ORDER BY
                    invbuy_qtyafter ASC
                LIMIT 1;    
        
        -- if really not found any inventory for sell
        -- then use last unitcost for this itemsite
        IF (NOT FOUND) THEN
            SELECT 
                (invhist_value_after - invhist_value_before)
                    / (invhist_qoh_after - invhist_qoh_before) AS unitcost
            FROM invhist INTO v_calc_unitcost
                WHERE 
                    invhist_itemsite_id = i_itemsite_id
                    AND
                    invhist_qoh_after - invhist_qoh_before <> 0
            ORDER BY invhist_transdate DESC, invhist_id DESC
            LIMIT 1;
        END IF;
        
        -- if not found any inventory of this itemsite
        -- then use standard cost for this itemsite
        IF (NOT FOUND) THEN
            v_calc_unitcost = stdcost(i_itemsite_id);
        END IF;    
        
        RETURN v_calc_unitcost;
    END IF;

    
    RETURN floor(( v_totalcost_avail/ v_qty_avail) * 1000) / 1000;
    
END
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
  
ALTER FUNCTION  itemcost_dispense(integer, numeric(18, 6))
  OWNER TO admin;
