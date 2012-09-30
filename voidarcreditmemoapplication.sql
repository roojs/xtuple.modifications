 
-- effort to void ar cm apply , so that invoice void works.. 
 
-- it basically creates a DM/CM pair and moves the application to that..
  
-- verify that curr_id on both source and target are the esame, if they are not, then we can not do this..



-- NEED TO VERIFY THIS WILL WORK

-- process : create invoice , create check payment and credit it- look at all gltrans that have been made..


-- before start last gltrans_id = 656889

-- GLTRANS:
-- Invoice  SALES (ADD) / AR (DEDUCT)
-- Check  AR (ADD) / Bank (DEDUCT)


-- AROPEN:
-- Only one item created.. - paid is filled in... (I)

-- ARAPPLY (id = 7475)
-- Funds type 'C'  sourcedoc = 'K' targetdoc = 'I'
--?? JOURNAL ENTRY?? - which one..

-- now try our CM/DM process.
-- Credit MEMO
-- aropon = doctype = 'C'
-- gltrans : AR (ADD) / Customer Credit (DEDUCT)

-- >> DM - set Prepaid account to Customer Credits...
-- aropen = doctype = 'D'
-- gltrans : AR( MINUS) / Customer Credit (ADD)

-- fundstype ==> 'emty'
-- refnumber ==> empty
-- journalnumber=> 0

-- reftype => blank
-- ref_id => null





CREATE OR REPLACE FUNCTION voidarcreditmemoapplication(integer)
  RETURNS integer AS
$BODY$
-- Copyright (c) 1999-2011 by OpenMFG LLC, d/b/a xTuple. 
-- See www.xtuple.com/CPAL for the full text of the software license.
DECLARE
    i_id ALIAS FOR $1;
    
    r_apply RECORD;
    
    v_source_curr_id  INTEGER;
    v_target_curr_id  INTEGER;
    
  
    v_debit_id  INTEGER;
    v_credit_id INTEGER;
    
    v_id INTEGER;

BEGIN
  
    -- the record we are voiding..
       
    SELECT
          *
        INTO
            r_apply
        FROM
            arapply
        WHERE
            arapply_id = i_id;
            
    IF NOT FOUND THEN
        RAISE EXCEPTION 'voidarcreditmemoapplication: arapply % not found', i_id;
    END IF;
    
    -- see if we have already done this..
    
    
    SELECT
            aropen_id
        INTO
            v_id
        FROM
            aropen
        WHERE
            aropen_docnumber = 'AR-APPLICATION-VOID-DEBIT-' || i_id
        LIMIT 1;
    
    IF FOUND THEN
        RAISE EXCEPTION 'this application has already been voided';
    END IF;
        
    
    
    -- fetch the currencies from the affected records..
    
    
    IF r_apply.arapply_source_doctype = 'K' THEN
        SELECT 
                cashrcpt_curr_id  
            INTO
                v_source_curr_id
            FROM
                cashrcpt
            WHERE
                cashrcpt_number = r_apply.arapply_source_docnumber;
                
    ELSE
        IF r_apply.arapply_source_aropen_id < 0 THEN
            RAISE EXCEPTION 'source_aropen_id < 0 - can not handle this.';
        END IF;
    
        SELECT
                aropen_curr_id
            INTO
                v_source_curr_id
            FROM
                aropen
            WHERE
                aropen_id = r_apply.arapply_source_aropen_id;
      
    
    END IF;
    
    IF r_apply.arapply_target_doctype = 'R' THEN
    
        -- there is a GL transaction for 'R' in applyarapplication....
        -- so we need to add that in later...
        RAISE EXCEPTION 'Target doctype = R not supported yet';
    END IF;
    
    IF r_apply.arapply_target_doctype = 'K' THEN
    
            SELECT
                cashrcpt_curr_id
            INTO
                v_target_curr_id
            FROM
                cashrcpt
            WHERE
                cashrcpt_number = r_apply.arapply_target_docnumber;
                
    ELSE
        IF r_apply.arapply_target_aropen_id < 0 THEN
            RAISE EXCEPTION 'source_aropen_id < 0 - can not handle this.';
        END IF;
    
    
        SELECT
              aropen_curr_id
            INTO
                v_target_curr_id
            FROM
                aropen
            WHERE
                aropen_id = r_apply.arapply_target_aropen_id;
    
    END IF;
    
    
   
    IF v_target_curr_id !=  v_source_curr_id THEN
        RAISE EXCEPTION 'voiding a application does not work yet...';
    END IF;

    
    -- now create a debit and credit to move the application to..
    
    
    SELECT createARCreditMemo (
        NULL,
        r_apply.arapply_cust_id,
       'AR-APPLICATION-VOID-CREDIT-' || i_id,
         '',
        r_apply.arapply_distdate,
        ABS(r_apply.arapply_target_paid),
        'AR Application Voided (Credit) -' || r_apply.arapply_refnumber,  
        -1,
        -1,
        -1, 
        r_apply.arapply_distdate,
        (SELECT cust_terms_id FROM custinfo where cust_id = r_apply.arapply_cust_id),
         (SELECT cust_salesrep_id FROM custinfo where cust_id = r_apply.arapply_cust_id),
        0,
         r_apply.arapply_curr_id
    ) INTO  v_credit_id;
    
    IF (v_credit_id < 1) THEN
        RAISE EXCEPTION 'createardebitmemo FAILED';
    END IF;
    
    
    
    SELECT createardebitmemo(
        NULL,
        r_apply.arapply_cust_id,
        NULL,
        'AR-APPLICATION-VOID-DEBIT-' || i_id,
        '',
        r_apply.arapply_distdate,
        ABS(r_apply.arapply_target_paid),
        'AR Application Voided (Debit) - ' || r_apply.arapply_refnumber,  
       
        -1,
        -1,
         (SELECT aropen_accnt_id FROM aropen where aropen_id = v_credit_id),
        r_apply.arapply_distdate,
        (SELECT cust_terms_id FROM custinfo where cust_id = r_apply.arapply_cust_id),
        (SELECT cust_salesrep_id FROM custinfo where cust_id = r_apply.arapply_cust_id),
        0,
        r_apply.arapply_curr_id
    ) INTO v_debit_id;
 
    IF (v_debit_id < 1) THEN
        RAISE EXCEPTION 'createardebitmemo FAILED';
    END IF;
    
    
    
    
    UPDATE arapply SET
       arapply_source_aropen_id = v_credit_id,
       arapply_source_doctype = 'C',
       arapply_source_docnumber = 'AR-APPLICATION-VOID-CREDIT-' || i_id,
       
       arapply_target_aropen_id = v_debit_id, 
       arapply_target_doctype = 'D',
       arapply_target_docnumber =  'AR-APPLICATION-VOID-DEBIT-' || i_id,
       arapply_fundstype = NULL,
       arapply_refnumber = NULL,
       arapply_journalnumber = 0 
 
    WHERE
       arapply_id     =  i_id;
 
 
    -- not sure if record will be updated by the above...
    -- hope not.. it would be a bit wierd...
    -- remove the payments from the apopen account - note that cashrecipts will
    -- not have a aropen_id (it's '-1' ) so they will get ignored.
    
    UPDATE
        aropen
    SET
        aropen_paid = aropen_paid - ABS(r_apply.arapply_target_paid),
        aropen_open = true,
        aropen_closedate = NULL
    WHERE
        aropen_id IN (r_apply.arapply_target_aropen_id  ,  r_apply.arapply_source_aropen_id) ;
    
    -- FOR OUR NEW ONES...
    UPDATE
        aropen
    SET
        aropen_paid = aropen_amount,
        aropen_open = false,
        aropen_closedate = r_apply.arapply_distdate
    WHERE
        aropen_id IN (v_credit_id, v_debit_id) ;
    
    
    RETURN i_id;
 
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION voidarcreditmemoapplication(integer)
  OWNER TO admin;
  
  
  
--select voidarcreditmemoapplication(7475);
--select voidarcreditmemoapplication(7477);
