CREATE OR REPLACE FUNCTION _soitemTrigger() RETURNS TRIGGER AS $$
-- Copyright (c) 1999-2012 by OpenMFG LLC, d/b/a xTuple. 
-- See www.xtuple.com/CPAL for the full text of the software license.
DECLARE
  _cmnttypeid INTEGER;
  _check BOOLEAN;
  _kit BOOLEAN;
  _shipped BOOLEAN;
  _atShipping NUMERIC;
  _tmp INTEGER;
  _rec RECORD;
BEGIN
  -- Check
  SELECT checkPrivilege('MaintainSalesOrders') OR checkPrivilege('ShipOrders') OR checkPrivilege('IssueStockToShipping') INTO _check;
  IF NOT (_check) THEN
    RAISE EXCEPTION 'You do not have privileges to alter a Sales Order.';
  END IF;

  IF (TG_OP IN ('INSERT','UPDATE')) THEN
    IF (NEW.coitem_scheddate IS NULL) THEN
      IF (fetchmetricbool('AllowASAPShipSchedules')) THEN
        NEW.coitem_scheddate := current_date;
      ELSE
        RAISE EXCEPTION 'A schedule date is required.';
      END IF;
    END IF;
  END IF;

  IF(TG_OP = 'DELETE') THEN
    _rec := OLD;
  ELSE
    _rec := NEW;
  END IF;
  SELECT COALESCE(item_type,'')='K'
    INTO _kit
    FROM itemsite, item
   WHERE((itemsite_item_id=item_id)
     AND (itemsite_id=_rec.coitem_itemsite_id));
  _kit := COALESCE(_kit, false);
  _shipped := false;
  IF(_kit AND _rec.coitem_status <> 'C' AND _rec.coitem_status <> 'X') THEN
    SELECT coitem_id
      INTO _tmp
      FROM coitem JOIN shipitem ON (shipitem_orderitem_id=coitem_id)
                  JOIN shiphead ON (shiphead_id=shipitem_shiphead_id AND shiphead_order_type='SO')
     WHERE((coitem_cohead_id=_rec.coitem_cohead_id)
       AND (coitem_linenumber=_rec.coitem_linenumber)
       AND (coitem_subnumber > 0))
     GROUP BY coitem_id
    HAVING (SUM(shipitem_qty) > 0)
     LIMIT 1;
    IF (FOUND) THEN
      _shipped := true;
    END IF;
  END IF;
  
  IF (TG_OP ='UPDATE') THEN
    IF ((OLD.coitem_status <> 'C') AND (NEW.coitem_status = 'C')) THEN
      SELECT qtyAtShipping(NEW.coitem_id) INTO _atShipping;
      IF (_atShipping > 0) THEN
        RAISE EXCEPTION 'Line % cannot be Closed at this time as there is inventory at shipping.',NEW.coitem_linenumber;
      END IF;
    END IF;
  END IF;

  IF ( SELECT (metric_value='t')
       FROM metric
       WHERE (metric_name='SalesOrderChangeLog') ) THEN
--  Cache the cmnttype_id for ChangeLog
    SELECT cmnttype_id INTO _cmnttypeid
    FROM cmnttype
    WHERE (cmnttype_name='ChangeLog');
  ELSE
    _cmnttypeid := -1;
  END IF;

  IF (TG_OP = 'INSERT') THEN
    INSERT INTO evntlog ( evntlog_evnttime, evntlog_username, evntlog_evnttype_id,
                          evntlog_ordtype, evntlog_ord_id, evntlog_warehous_id, evntlog_number )
    SELECT CURRENT_TIMESTAMP, evntnot_username, evnttype_id,
           'S', NEW.coitem_id, itemsite_warehous_id, (cohead_number || '-' || NEW.coitem_linenumber)
    FROM evntnot, evnttype, itemsite, item, cohead
    WHERE ( (evntnot_evnttype_id=evnttype_id)
     AND (evntnot_warehous_id=itemsite_warehous_id)
     AND (itemsite_id=NEW.coitem_itemsite_id)
     AND (itemsite_item_id=item_id)
     AND (NEW.coitem_cohead_id=cohead_id)
     AND (NEW.coitem_scheddate <= (CURRENT_DATE + itemsite_eventfence))
     AND (evnttype_name='SoitemCreated') );

    IF (_cmnttypeid <> -1) THEN
      PERFORM postComment(_cmnttypeid, 'SI', NEW.coitem_id, 'Created');
    END IF;

    --Set defaults if no values passed
    NEW.coitem_linenumber	:= COALESCE(NEW.coitem_linenumber,
                                          (SELECT (COALESCE(MAX(coitem_linenumber), 0) + 1)
                                           FROM coitem
                                           WHERE (coitem_cohead_id=NEW.coitem_cohead_id)));
    NEW.coitem_status		:= COALESCE(NEW.coitem_status,'O');
    NEW.coitem_scheddate	:= COALESCE(NEW.coitem_scheddate,
					   (SELECT MIN(coitem_scheddate)
					    FROM coitem
					    WHERE (coitem_cohead_id=NEW.coitem_cohead_id)));
    NEW.coitem_memo		:= COALESCE(NEW.coitem_memo,'');
    NEW.coitem_prcost		:= COALESCE(NEW.coitem_prcost,0);
    NEW.coitem_warranty	:= COALESCE(NEW.coitem_warranty,false);

    IF (NEW.coitem_status='O') THEN
      UPDATE cohead SET cohead_status = 'O'
       WHERE ((cohead_id=NEW.coitem_cohead_id)
         AND  (cohead_status='C'));
    END IF;

    RETURN NEW;

  ELSIF (TG_OP = 'DELETE') THEN

      IF(_kit) THEN
        IF(_shipped) THEN
          RAISE EXCEPTION 'You can not delete this Sales Order Line as it has several sub components that have already been shipped.';
        END IF;
      END IF;

      DELETE FROM comment
      WHERE ( (comment_source='SI')
       AND (comment_source_id=OLD.coitem_id) );

      DELETE FROM charass
       WHERE ((charass_target_type='SI')
         AND  (charass_target_id=OLD.coitem_id));
 
      IF ((OLD.coitem_order_type = 'W') AND
	  (SELECT wo_status IN ('O', 'E')
	    FROM wo
	    WHERE (wo_id=OLD.coitem_order_id))) THEN
        PERFORM deleteWo(OLD.coitem_order_id, TRUE);

      ELSIF (OLD.coitem_order_type = 'R') THEN 
        PERFORM deletePr(OLD.coitem_order_id);
      END IF;

    INSERT INTO evntlog ( evntlog_evnttime, evntlog_username,
			  evntlog_evnttype_id, evntlog_ordtype,
			  evntlog_ord_id, evntlog_warehous_id, evntlog_number )
    SELECT CURRENT_TIMESTAMP, evntnot_username,
	   evnttype_id, 'S',
	   OLD.coitem_id, itemsite_warehous_id,
	   (cohead_number || '-' || OLD.coitem_linenumber)
    FROM evntnot, evnttype, itemsite, item, cohead
    WHERE ( (evntnot_evnttype_id=evnttype_id)
     AND (evntnot_warehous_id=itemsite_warehous_id)
     AND (itemsite_id=OLD.coitem_itemsite_id)
     AND (itemsite_item_id=item_id)
     AND (OLD.coitem_cohead_id=cohead_id)
     AND (OLD.coitem_scheddate <= (CURRENT_DATE + itemsite_eventfence))
     AND (evnttype_name='SoitemCancelled') );

  ELSIF (TG_OP = 'UPDATE') THEN
    IF (NEW.coitem_qtyord <> OLD.coitem_qtyord) THEN
      IF(_kit) THEN
        IF(_shipped) THEN
          RAISE EXCEPTION 'You can not change the qty ordered for a Kit item when one or more of its components have shipped inventory.';
        END IF;
      END IF;
      INSERT INTO evntlog ( evntlog_evnttime, evntlog_username, evntlog_evnttype_id,
			    evntlog_ordtype, evntlog_ord_id, evntlog_warehous_id, evntlog_number,
			    evntlog_oldvalue, evntlog_newvalue )
      SELECT CURRENT_TIMESTAMP, evntnot_username, evnttype_id,
	     'S', NEW.coitem_id, itemsite_warehous_id, (cohead_number || '-' || NEW.coitem_linenumber),
	     OLD.coitem_qtyord, NEW.coitem_qtyord
      FROM evntnot, evnttype, itemsite, item, cohead
      WHERE ( (evntnot_evnttype_id=evnttype_id)
       AND (evntnot_warehous_id=itemsite_warehous_id)
       AND (itemsite_id=NEW.coitem_itemsite_id)
       AND (itemsite_item_id=item_id)
       AND (NEW.coitem_cohead_id=cohead_id)
       AND ( (NEW.coitem_scheddate <= (CURRENT_DATE + itemsite_eventfence))
	OR   (OLD.coitem_scheddate <= (CURRENT_DATE + itemsite_eventfence)) )
       AND (evnttype_name='SoitemQtyChanged') );

      IF (_cmnttypeid <> -1) THEN
	PERFORM postComment( _cmnttypeid, 'SI', NEW.coitem_id,
			     ( 'Changed Qty. Ordered from ' || formatQty(OLD.coitem_qtyord) ||
			       ' to ' || formatQty(NEW.coitem_qtyord) ) );
      END IF;

    END IF;

    IF (NEW.coitem_scheddate <> OLD.coitem_scheddate) THEN
      INSERT INTO evntlog ( evntlog_evnttime, evntlog_username, evntlog_evnttype_id,
			    evntlog_ordtype, evntlog_ord_id, evntlog_warehous_id, evntlog_number,
			    evntlog_olddate, evntlog_newdate )
      SELECT CURRENT_TIMESTAMP, evntnot_username, evnttype_id,
	     'S', NEW.coitem_id, itemsite_warehous_id, (cohead_number || '-' || NEW.coitem_linenumber),
	     OLD.coitem_scheddate, NEW.coitem_scheddate
      FROM evntnot, evnttype, itemsite, item, cohead
      WHERE ( (evntnot_evnttype_id=evnttype_id)
       AND (evntnot_warehous_id=itemsite_warehous_id)
       AND (itemsite_id=NEW.coitem_itemsite_id)
       AND (itemsite_item_id=item_id)
       AND (NEW.coitem_cohead_id=cohead_id)
       AND ( (NEW.coitem_scheddate <= (CURRENT_DATE + itemsite_eventfence))
	OR   (OLD.coitem_scheddate <= (CURRENT_DATE + itemsite_eventfence)) )
       AND (evnttype_name='SoitemSchedDateChanged') );

      IF (_cmnttypeid <> -1) THEN
	PERFORM postComment( _cmnttypeid, 'SI', NEW.coitem_id,
			     ( 'Changed Sched. Date from ' || formatDate(OLD.coitem_scheddate) ||
			       ' to ' || formatDate(NEW.coitem_scheddate)) );
      END IF;

    END IF;

    IF ((NEW.coitem_status = 'C') AND (OLD.coitem_status <> 'C')) THEN
      NEW.coitem_closedate = CURRENT_TIMESTAMP;
      NEW.coitem_close_username = getEffectiveXtUser();
      NEW.coitem_qtyreserved := 0;

      IF (_cmnttypeid <> -1) THEN
	PERFORM postComment(_cmnttypeid, 'SI', NEW.coitem_id, 'Closed');
      END IF;
    END IF;

    IF ((NEW.coitem_status <> 'C') AND (OLD.coitem_status = 'C')) THEN
      NEW.coitem_closedate = NULL;
      NEW.coitem_close_username = NULL;

      IF (_cmnttypeid <> -1) THEN
	PERFORM postComment(_cmnttypeid, 'SI', NEW.coitem_id, 'Reopened');
      END IF;
    END IF;

    IF ((NEW.coitem_status = 'X') AND (OLD.coitem_status <> 'X')) THEN
      IF ((OLD.coitem_order_type = 'W') AND
	  (SELECT wo_status IN ('O', 'E', 'R')
	    FROM wo
	    WHERE (wo_id=OLD.coitem_order_id))) THEN
      -- Close any associated W/O
        PERFORM closeWo(OLD.coitem_order_id, FALSE, CURRENT_DATE);
      ELSIF (OLD.coitem_order_type = 'R') THEN 
      -- Delete any associated P/R
        PERFORM deletePr(OLD.coitem_order_id);
      END IF;

      NEW.coitem_qtyreserved := 0;

      IF (_cmnttypeid <> -1) THEN
	PERFORM postComment(_cmnttypeid, 'SI', NEW.coitem_id, 'Canceled');
	PERFORM postComment(_cmnttypeid, 'S', NEW.coitem_cohead_id, 'Line # '|| NEW.coitem_linenumber ||' Canceled');
      END IF;

      INSERT INTO evntlog ( evntlog_evnttime, evntlog_username,
			    evntlog_evnttype_id, evntlog_ordtype,
			    evntlog_ord_id, evntlog_warehous_id, evntlog_number )
      SELECT CURRENT_TIMESTAMP, evntnot_username,
	     evnttype_id, 'S',
	     OLD.coitem_id, itemsite_warehous_id,
	     (cohead_number || '-' || OLD.coitem_linenumber)
      FROM evntnot, evnttype, itemsite, item, cohead
      WHERE ( (evntnot_evnttype_id=evnttype_id)
       AND (evntnot_warehous_id=itemsite_warehous_id)
       AND (itemsite_id=OLD.coitem_itemsite_id)
       AND (itemsite_item_id=item_id)
       AND (OLD.coitem_cohead_id=cohead_id)
       AND (OLD.coitem_scheddate <= (CURRENT_DATE + itemsite_eventfence))
       AND (evnttype_name='SoitemCancelled') );

    END IF;

    IF ((NEW.coitem_qtyreserved <> OLD.coitem_qtyreserved) AND (_cmnttypeid <> -1)) THEN
      PERFORM postComment(_cmnttypeid, 'SI', NEW.coitem_id, 'Changed Qty Reserved to '|| NEW.coitem_qtyreserved);
    END IF;

  END IF;

  IF (TG_OP = 'DELETE') THEN
    RETURN OLD;
  END IF;

  NEW.coitem_lastupdated = CURRENT_TIMESTAMP;

  -- Handle status for header
  IF (TG_OP = 'DELETE') THEN
    IF (OLD.coitem_status = 'O') THEN
      IF ( (SELECT (count(*) < 1)
              FROM coitem
             WHERE ((coitem_cohead_id=OLD.coitem_cohead_id)
               AND  (coitem_id != OLD.coitem_id)
               AND  (coitem_status = 'O')) ) ) THEN
        UPDATE cohead SET cohead_status = 'C'
         WHERE ((cohead_id=OLD.coitem_pohead_id)
           AND  (cohead_status='O'));
      END IF;
    END IF;

    RETURN OLD;
  END IF;

  IF (TG_OP = 'UPDATE') THEN
    IF (OLD.coitem_status <> NEW.coitem_status) THEN
      IF ( (SELECT (count(*) < 1)
              FROM coitem
             WHERE ((coitem_cohead_id=NEW.coitem_cohead_id)
               AND  (coitem_id != NEW.coitem_id)
               AND  (coitem_status='O')) ) AND (NEW.coitem_status<>'O') ) THEN
        UPDATE cohead SET cohead_status = 'C'
         WHERE ((cohead_id=NEW.coitem_cohead_id)
           AND  (cohead_status='O'));
      ELSE
        UPDATE cohead SET cohead_status = 'O'
         WHERE ((cohead_id=NEW.coitem_cohead_id)
           AND  (cohead_status='C'));
      END IF;
    END IF;
  END IF;

  RETURN NEW;

END;
$$ LANGUAGE 'plpgsql';

DROP TRIGGER soitemTrigger ON coitem;
CREATE TRIGGER soitemTrigger BEFORE INSERT OR UPDATE OR DELETE ON coitem FOR EACH ROW EXECUTE PROCEDURE _soitemTrigger();

CREATE OR REPLACE FUNCTION _soitemBeforeTrigger() RETURNS TRIGGER AS $$
-- Copyright (c) 1999-2012 by OpenMFG LLC, d/b/a xTuple. 
-- See www.xtuple.com/CPAL for the full text of the software license.
DECLARE
  _check NUMERIC;
  _itemNumber TEXT;
  _r RECORD;
  _kit BOOLEAN;

BEGIN

  --Determine if this is a kit for later processing
  SELECT COALESCE(item_type,'')='K'
  INTO _kit
  FROM itemsite, item
  WHERE((itemsite_item_id=item_id)
  AND (itemsite_id=NEW.coitem_itemsite_id));
  _kit := COALESCE(_kit, false);
  
  IF (TG_OP = 'INSERT') THEN

    -- If this is imported, go ahead and insert default characteristics
    IF (NEW.coitem_imported) THEN
      INSERT INTO charass (charass_target_type, charass_target_id, charass_char_id, charass_value, charass_price)
      SELECT 'SI', NEW.coitem_id, char_id, charass_value,
             itemcharprice(item_id,char_id,charass_value,cohead_cust_id,cohead_shipto_id,NEW.coitem_qtyord,cohead_curr_id,cohead_orderdate) 
        FROM (
           SELECT DISTINCT char_id, char_name, charass_value, item_id, cohead_cust_id, cohead_shipto_id, cohead_curr_id, cohead_orderdate
             FROM cohead, charass, char, itemsite, item
            WHERE((itemsite_id=NEW.coitem_itemsite_id)
              AND (itemsite_item_id=item_id)
              AND (charass_target_type='I') 
              AND (charass_target_id=item_id)
              AND (charass_default)
              AND (char_id=charass_char_id)
              AND (cohead_id=NEW.coitem_cohead_id))
           ORDER BY char_name) AS data;
    END IF;
  END IF;

  -- Create work order and process if flagged to do so
  IF ((NEW.coitem_order_type='W') AND (NEW.coitem_order_id=-1)) THEN
    SELECT createwo(CAST(cohead_number AS INTEGER),
                    NEW.coitem_itemsite_id,
                    1, -- priority
		    validateOrderQty(NEW.coitem_itemsite_id, NEW.coitem_qtyord, TRUE),
                    itemsite_leadtime,
                    NEW.coitem_scheddate,
		    NEW.coitem_memo,
                    'S',
                    NEW.coitem_id,
		    cohead_prj_id) INTO NEW.coitem_order_id
    FROM cohead, itemsite 
    WHERE ((cohead_id=NEW.coitem_cohead_id)
    AND (itemsite_id=NEW.coitem_itemsite_id));

    INSERT INTO charass
      (charass_target_type, charass_target_id,
       charass_char_id, charass_value) 
       SELECT 'W', NEW.coitem_order_id, charass_char_id, charass_value
       FROM charass
       WHERE ((charass_target_type='SI')
       AND  (charass_target_id=NEW.coitem_id));
  END IF;
   
  IF (TG_OP = 'UPDATE') THEN
--  Update P/R date if applicable

    IF (NEW.coitem_scheddate <> OLD.coitem_scheddate AND NEW.coitem_order_type='R' AND NEW.coitem_order_id > 1) THEN
      UPDATE pr SET pr_duedate = NEW.coitem_scheddate WHERE (pr_order_id=NEW.coitem_id AND pr_order_type='S');
    END IF;
    
--  If closing or cancelling and there is a job item work order, then close job and distribute remaining costs
    IF ((NEW.coitem_status = 'C' AND OLD.coitem_status <> 'C')
     OR (NEW.coitem_status = 'X' AND OLD.coitem_status <> 'X'))
     AND (OLD.coitem_order_id > -1) THEN

      SELECT wo_id, wo_wipvalue INTO _r
       FROM wo,itemsite,item
      WHERE ((wo_ordtype='S')
      AND (wo_ordid=OLD.coitem_id)
      AND (itemsite_id=wo_itemsite_id)
      AND (item_id=itemsite_item_id)
      AND (itemsite_costmethod = 'J'));

      IF (FOUND) THEN
        IF (_r.wo_wipvalue > 0) THEN
        --  Distribute to G/L, debit Cost of Sales, credit WIP
          PERFORM MIN(insertGLTransaction( 'W/O', 'WO', formatWoNumber(NEW.coitem_order_id), 'Job Closed Incomplete',
                                       costcat_wip_accnt_id,
				        CASE WHEN(COALESCE(NEW.coitem_cos_accnt_id, -1) != -1) THEN NEW.coitem_cos_accnt_id
                                          WHEN(NEW.coitem_warranty=TRUE) THEN resolveCOWAccount(itemsite_id, cohead_cust_id)
                                          ELSE resolveCOSAccount(itemsite_id, cohead_cust_id)
                                       END,
                                       -1,  _r.wo_wipvalue, current_date ))
          FROM itemsite, costcat, cohead
          WHERE ((itemsite_id=NEW.coitem_itemsite_id)
           AND (itemsite_costcat_id=costcat_id)
           AND (cohead_id=NEW.coitem_cohead_id));
        END IF;

        UPDATE wo SET
          wo_status = 'C',
          wo_wipvalue = 0
        WHERE (wo_id = _r.wo_id);

      END IF;
    END IF;

--  Likewise, reopen the job if line reopened
    IF ((NEW.coitem_status != 'C' AND OLD.coitem_status = 'C')
     OR (NEW.coitem_status != 'X' AND OLD.coitem_status = 'X'))
     AND (OLD.coitem_order_id > -1) THEN
        UPDATE wo SET
          wo_status = 'I'
        FROM itemsite, item
        WHERE ((wo_ordtype = 'S')
         AND (wo_ordid=NEW.coitem_id)
         AND (wo_itemsite_id=itemsite_id)
         AND (itemsite_item_id=item_id)
         AND (itemsite_costmethod='J'));
    END IF;

--  Handle links to Return Authorization
    IF (fetchMetricBool('EnableReturnAuth')) THEN 
      SELECT * INTO _r 
      FROM raitem,rahead 
      WHERE ((raitem_new_coitem_id=NEW.coitem_id)
      AND (rahead_id=raitem_rahead_id));
      IF (FOUND) THEN
        IF ((_r.raitem_qtyauthorized <> NEW.coitem_qtyord OR
            _r.raitem_qty_uom_id <> NEW.coitem_qty_uom_id OR
            _r.raitem_qty_invuomratio <> NEW.coitem_qty_invuomratio OR
            _r.raitem_price_uom_id <> NEW.coitem_price_uom_id OR
            _r.raitem_price_invuomratio <> NEW.coitem_price_invuomratio)
            AND NOT (NEW.coitem_status = 'X' AND _r.raitem_qtyauthorized = 0)) THEN
          RAISE EXCEPTION 'Quantities for line item % may only be changed on the Return Authorization that created it.',NEW.coitem_linenumber;
        END IF;
        IF (OLD.coitem_warranty <> NEW.coitem_warranty) THEN
          UPDATE raitem SET raitem_warranty = NEW.coitem_warranty
           WHERE((raitem_new_coitem_id=NEW.coitem_id)
             AND (raitem_warranty != NEW.coitem_warranty));
        END IF;
        IF (OLD.coitem_cos_accnt_id <> NEW.coitem_cos_accnt_id) THEN
          UPDATE raitem SET raitem_cos_accnt_id = NEW.coitem_cos_accnt_id
           WHERE((raitem_new_coitem_id=NEW.coitem_id)
             AND (COALESCE(raitem_cos_accnt_id,-1) != COALESCE(NEW.coitem_cos_accnt_id,-1)));
        END IF;
        IF (OLD.coitem_taxtype_id <> NEW.coitem_taxtype_id) THEN
          UPDATE raitem SET raitem_taxtype_id = NEW.coitem_taxtype_id
           WHERE((raitem_new_coitem_id=NEW.coitem_id)
             AND (COALESCE(raitem_taxtype_id,-1) != COALESCE(NEW.coitem_taxtype_id,-1)));
        END IF;
        IF (OLD.coitem_scheddate <> NEW.coitem_scheddate) THEN
          UPDATE raitem SET raitem_scheddate = NEW.coitem_scheddate
           WHERE((raitem_new_coitem_id=NEW.coitem_id)
             AND (raitem_scheddate != NEW.coitem_scheddate));
        END IF;
        IF (OLD.coitem_memo <> NEW.coitem_memo) THEN
          UPDATE raitem SET raitem_notes = NEW.coitem_memo
           WHERE((raitem_new_coitem_id=NEW.coitem_id)
             AND (raitem_notes != NEW.coitem_memo));
        END IF;
        IF ((OLD.coitem_qtyshipped <> NEW.coitem_qtyshipped) AND 
           (NEW.coitem_qtyshipped >= _r.raitem_qtyauthorized) AND
           ((_r.raitem_disposition = 'S') OR
           (_r.raitem_status = 'O') AND
           (_r.raitem_disposition IN ('P','V')) AND
           (_r.raitem_qtyreceived >= _r.raitem_qtyauthorized))) THEN
          UPDATE raitem SET raitem_status = 'C' 
          WHERE (raitem_new_coitem_id=NEW.coitem_id);
        END IF;
      END IF;
    END IF; 
  END IF; 

  RETURN NEW;
END;
$$ LANGUAGE 'plpgsql';

DROP TRIGGER soitemBeforeTrigger ON coitem;
CREATE TRIGGER soitemBeforeTrigger BEFORE INSERT OR UPDATE ON coitem FOR EACH ROW EXECUTE PROCEDURE _soitemBeforeTrigger();
-- TODO: there are two BEFORE triggers. should these be merged?


CREATE OR REPLACE FUNCTION _soitemAfterTrigger() RETURNS TRIGGER AS $$
-- Copyright (c) 1999-2012 by OpenMFG LLC, d/b/a xTuple. 
-- See www.xtuple.com/CPAL for the full text of the software license.
DECLARE
  _check NUMERIC;
  _custID INTEGER;
  _po BOOLEAN;
  _kit BOOLEAN;
  _fractional BOOLEAN;
  _purchase BOOLEAN;
  _rec RECORD;
  _kstat TEXT;
  _pstat TEXT;
  _result INTEGER;
  _coitemid INTEGER;
  _itemsrcid INTEGER;

BEGIN

  IF(TG_OP = 'DELETE') THEN
    _rec := OLD;
  ELSE
    _rec := NEW;
  END IF;

  --Cache some information
  SELECT cohead_cust_id INTO _custID
  FROM cohead
  WHERE (cohead_id=_rec.coitem_cohead_id);

  --Determine if this is a kit for later processing
  SELECT COALESCE(item_type,'')='K', item_fractional
    INTO _kit, _fractional
    FROM itemsite, item
   WHERE((itemsite_item_id=item_id)
     AND (itemsite_id=_rec.coitem_itemsite_id));
  _kit := COALESCE(_kit, false);
  _fractional := COALESCE(_fractional, false);

 --Select purchase items
  SELECT COALESCE(item_type,'')='P'
    INTO _purchase
    FROM itemsite JOIN item ON (itemsite_item_id=item_id)
   WHERE (itemsite_id=_rec.coitem_itemsite_id);
  _purchase := COALESCE(_purchase, false);
 
 --Select salesorder related to purchaseorder 
  SELECT itemsite_createsopo INTO _po 
  FROM itemsite JOIN coitem ON  (itemsite_id=coitem_itemsite_id) 
  WHERE (coitem_id=_rec.coitem_id);

  IF (_kit) THEN
  -- Kit Processing
    IF (TG_OP = 'INSERT') THEN
  -- Create Sub Lines for Kit Components
      PERFORM explodeKit(NEW.coitem_cohead_id, NEW.coitem_linenumber, 0, NEW.coitem_itemsite_id,
                         NEW.coitem_qtyord, NEW.coitem_scheddate, NEW.coitem_promdate, NEW.coitem_memo);
      IF (fetchMetricBool('KitComponentInheritCOS')) THEN
  -- Update kit line item COS
        UPDATE coitem
        SET coitem_cos_accnt_id = CASE WHEN (COALESCE(NEW.coitem_cos_accnt_id, -1) != -1) THEN NEW.coitem_cos_accnt_id
                                       WHEN (NEW.coitem_warranty) THEN resolveCOWAccount(NEW.coitem_itemsite_id, _custID)
                                       ELSE resolveCOSAccount(NEW.coitem_itemsite_id, _custID)
                                  END
        WHERE((coitem_cohead_id=NEW.coitem_cohead_id)
          AND (coitem_linenumber = NEW.coitem_linenumber)
          AND (coitem_subnumber > 0));
      END IF;
    END IF;
    IF (TG_OP = 'UPDATE') THEN
      IF (NEW.coitem_qtyord <> OLD.coitem_qtyord) THEN
  -- Recreate Sub Lines for Kit Components
      FOR _coitemid IN
        SELECT coitem_id
        FROM coitem
        WHERE ( (coitem_cohead_id=OLD.coitem_cohead_id)
          AND   (coitem_linenumber=OLD.coitem_linenumber)
          AND   (coitem_subnumber > 0) )
        LOOP
          SELECT deleteSoItem(_coitemid) INTO _result;
          IF (_result < 0) THEN
             RAISE EXCEPTION 'Error deleting kit components: deleteSoItem(integer) Error:%', _result;
          END IF;
        END LOOP;

        PERFORM explodeKit(NEW.coitem_cohead_id, NEW.coitem_linenumber, 0, NEW.coitem_itemsite_id,
                           NEW.coitem_qtyord, NEW.coitem_scheddate, NEW.coitem_promdate);
      END IF;
      IF ( (NEW.coitem_qtyord <> OLD.coitem_qtyord) OR
           (NEW.coitem_cos_accnt_id <> OLD.coitem_cos_accnt_id) ) THEN
        IF (fetchMetricBool('KitComponentInheritCOS')) THEN
  -- Update kit line item COS
          UPDATE coitem
          SET coitem_cos_accnt_id = CASE WHEN (COALESCE(NEW.coitem_cos_accnt_id, -1) != -1) THEN NEW.coitem_cos_accnt_id
                                         WHEN (NEW.coitem_warranty) THEN resolveCOWAccount(NEW.coitem_itemsite_id, _custID)
                                         ELSE resolveCOSAccount(NEW.coitem_itemsite_id, _custID)
                                    END
          WHERE((coitem_cohead_id=NEW.coitem_cohead_id)
            AND (coitem_linenumber = NEW.coitem_linenumber)
            AND (coitem_subnumber > 0));
        END IF;
      END IF;
      IF (NEW.coitem_scheddate <> OLD.coitem_scheddate) THEN
  -- Update kit line item Schedule Date
        UPDATE coitem
        SET coitem_scheddate = NEW.coitem_scheddate
        WHERE((coitem_cohead_id=NEW.coitem_cohead_id)
          AND (coitem_linenumber = NEW.coitem_linenumber)
          AND (coitem_subnumber > 0));
      END IF;
    END IF;
    IF (TG_OP = 'DELETE') THEN
  -- Delete Sub Lines for Kit Components
     FOR _coitemid IN
        SELECT coitem_id
        FROM coitem
        WHERE ( (coitem_cohead_id=OLD.coitem_cohead_id)
          AND   (coitem_linenumber=OLD.coitem_linenumber)
          AND   (coitem_subnumber > 0) )
      LOOP
        SELECT deleteSoItem(_coitemid) INTO _result;
        IF (_result < 0) THEN
          IF NOT (_po AND (_result = -10 OR _result = -20)) THEN
            RAISE EXCEPTION 'Error deleting kit components: deleteSoItem(integer) Error:%', _result;
          END IF;
        END IF;
      END LOOP;
    END IF;
  END IF;

  IF (TG_OP = 'INSERT') THEN
    -- Create Purchase Request if flagged to do so
    IF ((NEW.coitem_order_type='R') AND (NEW.coitem_order_id=-1)) THEN
      SELECT createpr(CAST(cohead_number AS INTEGER), 'S', NEW.coitem_id) INTO NEW.coitem_order_id
      FROM cohead
      WHERE (cohead_id=NEW.coitem_cohead_id);
    END IF;

    -- Create Purchase Order if flagged to do so
    IF ((NEW.coitem_order_type='P') AND (NEW.coitem_order_id=-1)) THEN
      SELECT itemsrc_id INTO _itemsrcid
      FROM itemsite JOIN itemsrc ON (itemsrc_item_id=itemsite_item_id AND itemsrc_default)
      WHERE (itemsite_id=NEW.coitem_itemsite_id);
      IF (FOUND) THEN
        SELECT createPurchaseToSale(NEW.coitem_id,
                                    _itemsrcid,
                                    itemsite_dropship,
                                    CASE WHEN (NEW.coitem_prcost=0.0) THEN NULL
                                         ELSE NEW.coitem_prcost
                                    END) INTO NEW.coitem_order_id
        FROM itemsite
        WHERE (itemsite_id=NEW.coitem_itemsite_id);
      END IF;
    END IF;
  END IF;

  IF (_purchase) THEN
    --For purchase item processing
--    IF (fetchmetricbool('EnableDropShipments')) THEN
--      --Dropship processing
      IF(_po) THEN
        IF (TG_OP = 'UPDATE') THEN
          IF ((NEW.coitem_qtyord <> OLD.coitem_qtyord) OR (NEW.coitem_qty_invuomratio <> OLD.coitem_qty_invuomratio) OR (NEW.coitem_scheddate <> OLD.coitem_scheddate)) THEN
            --Update related poitem
            UPDATE poitem
            SET poitem_qty_ordered = roundQty(_fractional, (NEW.coitem_qtyord * NEW.coitem_qty_invuomratio / poitem_invvenduomratio)),
                poitem_duedate = NEW.coitem_scheddate 
            WHERE (poitem_id = OLD.coitem_order_id);

            --Generate the PoItemUpdatedBySo event
            INSERT INTO evntlog
                        ( evntlog_evnttime, evntlog_username, evntlog_evnttype_id,
                          evntlog_ordtype, evntlog_ord_id, evntlog_warehous_id,
                          evntlog_number )
            SELECT CURRENT_TIMESTAMP, evntnot_username, evnttype_id,
              'P', poitem_id, itemsite_warehous_id,
            (pohead_number || '-'|| poitem_linenumber || ': ' || item_number)
            FROM evntnot JOIN evnttype ON (evntnot_evnttype_id=evnttype_id)
                 JOIN itemsite ON (evntnot_warehous_id=itemsite_warehous_id)
                 JOIN item ON (itemsite_item_id=item_id)
                 JOIN poitem ON (poitem_itemsite_id=itemsite_id)
                 JOIN pohead ON (poitem_pohead_id=pohead_id)
            WHERE( (poitem_id=OLD.coitem_order_id)
            AND (poitem_duedate <= (CURRENT_DATE + itemsite_eventfence))
            AND (evnttype_name='PoItemUpdatedBySo') );
          END IF;

          --If soitem is cancelled
          IF ((NEW.coitem_status = 'X') AND (OLD.coitem_status <> 'X')) THEN
            --Generate the PoItemSoCancelled event
            INSERT INTO evntlog
                        ( evntlog_evnttime, evntlog_username, evntlog_evnttype_id,
                          evntlog_ordtype, evntlog_ord_id, evntlog_warehous_id,
                          evntlog_number )
            SELECT CURRENT_TIMESTAMP, evntnot_username, evnttype_id,
            'P', poitem_id, itemsite_warehous_id,
            (pohead_number || '-' || poitem_linenumber || ': ' || item_number)
            FROM evntnot JOIN evnttype ON (evntnot_evnttype_id=evnttype_id)
                 JOIN itemsite ON (evntnot_warehous_id=itemsite_warehous_id)
                 JOIN item ON (itemsite_item_id=item_id)
                 JOIN poitem ON (poitem_itemsite_id=itemsite_id)
            JOIN pohead ON( poitem_pohead_id=pohead_id)
            WHERE( (poitem_id=OLD.coitem_order_id)
            AND (poitem_duedate <= (CURRENT_DATE + itemsite_eventfence))
            AND (evnttype_name='PoItemSoCancelled') );
          END IF;
        END IF;
      END IF; 
--    END IF;
  END IF;

  IF (_rec.coitem_subnumber > 0) THEN
    SELECT coitem_status
      INTO _kstat
      FROM coitem
     WHERE((coitem_cohead_id=_rec.coitem_cohead_id)
       AND (coitem_linenumber=_rec.coitem_linenumber)
       AND (coitem_subnumber = 0));
    IF ((SELECT count(*)
           FROM coitem
          WHERE((coitem_cohead_id=_rec.coitem_cohead_id)
            AND (coitem_linenumber=_rec.coitem_linenumber)
            AND (coitem_subnumber <> _rec.coitem_subnumber)
            AND (coitem_subnumber > 0)
            AND (coitem_status = 'O'))) > 0) THEN
      _pstat := 'O';
    ELSE
      _pstat := _rec.coitem_status;
    END IF;
  END IF;

  IF(TG_OP = 'INSERT') THEN
    IF (_rec.coitem_subnumber > 0 AND _rec.coitem_status = 'O') THEN
      _pstat := 'O';
    END IF;
  ELSIF (TG_OP = 'UPDATE') THEN
    IF (_rec.coitem_subnumber > 0 AND _rec.coitem_status = 'O') THEN
      _pstat := 'O';
    END IF;

    IF ((NEW.coitem_status = 'C') AND (OLD.coitem_status <> 'C')) THEN
      IF(_kit) THEN
        UPDATE coitem
           SET coitem_status='C'
         WHERE((coitem_cohead_id=OLD.coitem_cohead_id)
           AND (coitem_linenumber=OLD.coitem_linenumber)
           AND (coitem_status='O')
           AND (coitem_subnumber > 0));
      END IF;
    END IF;

    IF ((NEW.coitem_status = 'X') AND (OLD.coitem_status <> 'X')) THEN
      IF(_kit) THEN
        UPDATE coitem
           SET coitem_status='X'
         WHERE((coitem_cohead_id=OLD.coitem_cohead_id)
           AND (coitem_linenumber=OLD.coitem_linenumber)
           AND (coitem_status='O')
           AND (coitem_subnumber > 0));
      END IF;
    END IF;

    IF(NEW.coitem_status = 'O' AND OLD.coitem_status <> 'O') THEN
      IF(_kit) THEN
        UPDATE coitem
           SET coitem_status='O'
         WHERE((coitem_cohead_id=OLD.coitem_cohead_id)
           AND (coitem_linenumber=OLD.coitem_linenumber)
           AND ((coitem_qtyord - coitem_qtyshipped + coitem_qtyreturned) > 0)
           AND (coitem_subnumber > 0));
      END IF;
    END IF;

  END IF;

  IF ((_kstat IS NOT NULL) AND (_pstat IS NOT NULL) AND (_rec.coitem_subnumber > 0) AND (_kstat <> _pstat)) THEN
    UPDATE coitem
       SET coitem_status = _pstat
     WHERE((coitem_cohead_id=_rec.coitem_cohead_id)
       AND (coitem_linenumber=_rec.coitem_linenumber)
       AND (coitem_subnumber = 0));
  END IF;

  IF(TG_OP = 'DELETE') THEN
    RETURN OLD;
  END IF;

  --If auto calculate freight, recalculate cohead_freight
  IF (SELECT cohead_calcfreight FROM cohead WHERE (cohead_id=NEW.coitem_cohead_id)) THEN
    UPDATE cohead SET cohead_freight = COALESCE(
      (SELECT SUM(freightdata_total) FROM freightDetail('SO',
                                                        cohead_id,
                                                        cohead_cust_id,
                                                        cohead_shipto_id,
                                                        cohead_orderdate,
                                                        cohead_shipvia,
                                                        cohead_curr_id)), 0)
    WHERE cohead_id=NEW.coitem_cohead_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE 'plpgsql';

SELECT dropIfExists('TRIGGER', 'soitemAfterTrigger');
CREATE TRIGGER soitemAfterTrigger AFTER INSERT OR UPDATE OR DELETE ON coitem FOR EACH ROW EXECUTE PROCEDURE _soitemAfterTrigger();
