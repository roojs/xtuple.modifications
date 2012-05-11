



CREATE OR REPLACE FUNCTION explodekitmustdelete(integer, integer, integer, integer)
 RETURNS integer AS
$BODY$
DECLARE
     pSoheadid ALIAS FOR $1;
  pLinenumber ALIAS FOR $2;
  pSubnumber ALIAS FOR $3;
  pItemsiteid ALIAS FOR $4;
  _warehousid INTEGER;
  _itemid INTEGER;
  _revid INTEGER;

  _ret INTEGER;
  
BEGIN
    
  SELECT getActiveRevId('BOM',itemsite_item_id), itemsite_warehous_id, itemsite_item_id
    INTO _revid, _warehousid, _itemid
    FROM itemsite
   WHERE(itemsite_id=pItemsiteid);
  IF(NOT FOUND) THEN
    RAISE EXCEPTION 'No Item Site for the specified line was found.';
  END IF;
    
    SELECT count(itemsite_id) INTO _ret
  
        FROM bomitem JOIN item ON (item_id=bomitem_item_id)
             LEFT OUTER JOIN itemsite ON ((itemsite_item_id=item_id) AND (itemsite_warehous_id=_warehousid))
        WHERE((bomitem_parent_item_id=_itemid)
            AND (bomitem_rev_id=_revid)
            AND (CURRENT_DATE BETWEEN bomitem_effective AND (bomitem_expires - 1)))
            AND  itemsite_createsopr = true 
            AND itemsite_createsopo = true 
            AND itemsite_createwo = true;
             
    if (_ret > 0) THEN
        RETURN _ret;
    END IF;
    
    SELECT count(coitem_id) INTO _ret
        FROM
            coitem
        WHERE
            coitem_cohead_id = pSoheadid
            AND 
            coitem_linenumber = pLinenumber
            AND 
            coitem_subnumber > 0
            AND
            coitem_order_type IS NOT NULL
        LIMIT 1;
    
    RETURN _ret;
    
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION explodekitmustdelete(integer, integer, integer, integer)
  OWNER TO admin;


-- Function: explodekit(integer, integer, integer, integer, numeric, date, date, text)

-- DROP FUNCTION explodekit(integer, integer, integer, integer, numeric, date, date, text);

CREATE OR REPLACE FUNCTION explodekit(integer, integer, integer, integer, numeric, date, date, text)
  RETURNS integer AS
$BODY$
DECLARE
  pSoheadid ALIAS FOR $1;
  pLinenumber ALIAS FOR $2;
  pSubnumber ALIAS FOR $3;
  pItemsiteid ALIAS FOR $4;
  pQty ALIAS FOR $5;
  pScheddate ALIAS FOR $6;
  pPromdate ALIAS FOR $7;
  pMemo ALIAS FOR $8;
  _subnumber INTEGER := COALESCE(pSubnumber,0);
  _revid INTEGER;
  _itemid INTEGER;
  _warehousid INTEGER;
  _item RECORD;
  _type TEXT;
  _coitemid INTEGER;
  _count INTEGER;
  _orderid INTEGER := 0;
  _itemsrcid INTEGER;
  _hascreates INTEGER;
BEGIN

  SELECT getActiveRevId('BOM',itemsite_item_id), itemsite_warehous_id, itemsite_item_id
    INTO _revid, _warehousid, _itemid
    FROM itemsite
   WHERE(itemsite_id=pItemsiteid);
  IF(NOT FOUND) THEN
    RAISE EXCEPTION 'No Item Site for the specified line was found.';
  END IF;

-- if any of the items have    itemsite_createsopr or itemsite_createsopo
-- then we have to trash all the items before starting..
  
    
     

  FOR _item IN
  SELECT bomitem_id, 
         itemsite_id,
         itemsite_warehous_id,
         COALESCE((itemsite_active AND item_active), false) AS active,
         COALESCE((itemsite_sold AND item_sold), false) AS sold,
         item_id,
         item_type,
         item_price_uom_id,
         itemsite_createsopr,itemsite_createwo,itemsite_createsopo, itemsite_dropship,
         bomitem_uom_id,
         itemuomtouomratio(item_id, bomitem_uom_id, item_inv_uom_id) AS invuomratio,
         roundQty(itemuomfractionalbyuom(bomitem_item_id, bomitem_uom_id),(bomitem_qtyfxd + bomitem_qtyper * pQty) * (1 + bomitem_scrap)) AS qty
    FROM bomitem JOIN item ON (item_id=bomitem_item_id)
                  LEFT OUTER JOIN itemsite ON ((itemsite_item_id=item_id) AND (itemsite_warehous_id=_warehousid))
   WHERE((bomitem_parent_item_id=_itemid)
     AND (bomitem_rev_id=_revid)
     AND (CURRENT_DATE BETWEEN bomitem_effective AND (bomitem_expires - 1)))
   ORDER BY bomitem_seqnumber LOOP
   
    IF (NOT _item.active) THEN
      RAISE EXCEPTION 'One or more of the components for the kit is inactive for the selected item site.';
    ELSIF (NOT _item.sold) THEN
      RAISE EXCEPTION 'One or more of the components for the kit is not sold for the selected item site.';
    ELSIF (_item.item_type='F') THEN
      -- not sure what this does?? F=???
      
    
      SELECT explodeKit(pSoheadid, pLinenumber, _subnumber, _item.itemsite_id, _item.qty)
        INTO _subnumber;
    ELSE
      IF (_item.itemsite_createsopr) THEN
        _type := 'R';
      ELSIF (_item.itemsite_createsopo) THEN
        _type := 'P';
      ELSIF (_item.itemsite_createwo) THEN
        _type := 'W';
      ELSE
        _type := NULL;
      END IF;
      _subnumber := _subnumber + 1;
      
      -- IF THE LINE EXISTS.. then update. it..
      
      SELECT coitem_id FROM coitem INTO _coitemid WHERE 
        coitem_cohead_id = pSoheadid
        AND 
        coitem_linenumber = pLinenumber
        AND 
        coitem_subnumber = _subnumber
        LIMIT 1;
     
      IF (NOT FOUND) THEN 
      
        
        _coitemid = nextval('coitem_coitem_id_seq');
        raise notice 'coitem id: %',_coitemid;
        INSERT INTO coitem
              (coitem_id, coitem_cohead_id,
               coitem_linenumber, coitem_subnumber,
               coitem_itemsite_id, coitem_status,
               coitem_scheddate, coitem_promdate,
               coitem_qtyord, coitem_qty_uom_id, coitem_qty_invuomratio,
               coitem_qtyshipped, coitem_qtyreturned,
               coitem_unitcost, coitem_custprice,
               coitem_price, coitem_price_uom_id, coitem_price_invuomratio,
               coitem_order_type, coitem_order_id,
               coitem_custpn, coitem_memo,
               coitem_prcost)
        VALUES (_coitemid, pSoheadid,
               pLinenumber, _subnumber,
               _item.itemsite_id, 'O',
               pScheddate, pPromdate,
               _item.qty, _item.bomitem_uom_id, _item.invuomratio,
               0, 0,
               stdCost(_item.item_id), 0,
               0, _item.item_price_uom_id, 1,
               _type, -1,
               '', pMemo,
               0);
     ELSE
        IF (_type IS NOT NULL) THEN
        
            RAISE EXCEPTION 'can not update coitems - use explodekitcanupdate to check first';
        END IF;
      
        UPDATE coitem SET
       
               coitem_itemsite_id = _item.itemsite_id    , 
               coitem_status =   'O', 
               coitem_scheddate =  pScheddate  ,
               coitem_promdate =   pPromdate ,
               coitem_qtyord = _item.qty   ,
               coitem_qty_uom_id =  _item.bomitem_uom_id   ,
               coitem_qty_invuomratio =   _item.invuomratio  ,
               coitem_qtyshipped =  0  ,
               coitem_qtyreturned = 0   ,
               coitem_unitcost = stdCost(_item.item_id)   ,
               coitem_custprice = 0   ,
               coitem_price =  0 ,
               coitem_price_uom_id =   _item.item_price_uom_id   ,
               coitem_price_invuomratio =   1 ,
               coitem_order_type =  _type  ,
               coitem_order_id =  -1  ,
               coitem_custpn =   '' ,
               coitem_memo =  pMemo  ,
               coitem_prcost = 0
               
         WHERE coitem_id = _coitemid;
      
      END IF;
       
      
      IF (_item.itemsite_createsopr) THEN
        SELECT createPR(cohead_number::INTEGER, 'S', _coitemid) INTO _orderid
            FROM cohead
            WHERE (cohead_id=pSoheadid);
        IF (_orderid > 0) THEN
          UPDATE coitem SET coitem_order_id=_orderid
            WHERE (coitem_id=_coitemid);
        ELSE
          RAISE EXCEPTION 'Could not explode kit. CreatePR failed, result=%', _orderid; 
        END IF;
      END IF;

      IF (_item.itemsite_createsopo) THEN
        SELECT itemsrc_id INTO _itemsrcid
        FROM itemsrc
        WHERE ((itemsrc_item_id=_item.item_id)
        AND (itemsrc_default));

        GET DIAGNOSTICS _count = ROW_COUNT;
        IF (_count > 0) THEN
          PERFORM createPurchaseToSale(_coitemid, _itemsrcid, _item.itemsite_dropship);
        ELSE
          RAISE EXCEPTION 'Could not explode kit.  One or more items are flagged as purchase-to-order for this site, but no default item source is defined.';
        END IF;
      END IF;
     
    END IF;
  END LOOP;

  RETURN _subnumber;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION explodekit(integer, integer, integer, integer, numeric, date, date, text)
  OWNER TO admin;



 
