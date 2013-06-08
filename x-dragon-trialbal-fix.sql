--rebuild trialbal... -- after an oops in AU..

CREATE OR REPLACE FUNCTION trialbal_check(i_id integer)
  RETURNS boolean AS
$BODY$
DECLARE
  
    v_start DATE;
    v_end DATE;
    v_accnt_id INTEGER;
    v_pre_credits NUMERIC;
    v_pre_debits NUMERIC;
    v_pre_beginning NUMERIC;
    v_pre_ending NUMERIC;
    v_beginning NUMERIC;
    v_credits NUMERIC;
    v_debits NUMERIC;
    v_accnt_descrip TEXT;
     v_accnt_type TEXT;
    v_yearperiod_start DATE;
BEGIN
    
   
   SELECT
       period_start,
       period_end,
       trialbal_accnt_id,
       trialbal_credits,
       trialbal_debits,
       trialbal_beginning,
       trialbal_ending,
       accnt_descrip,
       accnt_type,
       yearperiod_start
   INTO
       v_start,
       v_end,
       v_accnt_id,
       v_pre_credits,
       v_pre_debits,
       v_pre_beginning,
       v_pre_ending,
       v_accnt_descrip,
       v_accnt_type,
       v_yearperiod_start
   FROM
       trialbal
   LEFT JOIN
       period
   ON
       period_id = trialbal_period_id
    LEFT JOIN
        yearperiod
    ON
        yearperiod_id = period_yearperiod_id
       
    LEFT JOIN
        accnt
    ON
        accnt_id = trialbal_accnt_id
   WHERE
       trialbal_id = i_id;
       
    IF strpos(v_accnt_descrip, 'Retained Earn') > 0	 THEN
        return false;
    END IF;
    --IF v_accnt_id =  134 THEN -- opening balance has unrecorded transactions!??
    --    return false;
    --END IF;
    --IF i_id =  22395 OR i_id = 17371 or i_id = 17372  OR i_id = 17373 OR i_id = 22396 THEN -- $0.01
    --    return false;
    --END IF;
   
   -- this beginning amount differs depending
   -- on if it's carried forward each year or not..
   
   -- expense : $0 at beginning of financial year..
    
    -- assets start for ever..
    
    if v_accnt_type = 'A' OR v_accnt_type = 'L'  OR v_accnt_type = 'Q'  THEN
         v_yearperiod_start = '1970-01-01'::date; 
    END IF;
   
   
   
   SELECT
       COALESCE(sum(
             ROUND(gltrans_amount,2)
       ),0)
       INTO
           v_beginning
       FROM
           gltrans 
       where
           gltrans_date < v_start
        AND
            gltrans_date >=  v_yearperiod_start
       AND 
           gltrans_accnt_id = v_accnt_id
       AND
           gltrans_posted
        AND
            NOT gltrans_deleted;
   
   
   SELECT
       
       COALESCE(sum(
           CASE WHEN  gltrans_amount > 0 THEN ROUND(gltrans_amount,2) ELSE 0 END 
       ),0) ,
       COALESCE(sum(
           CASE WHEN  gltrans_amount < 0 THEN ROUND(gltrans_amount,2) ELSE 0 END 
       ),0)  
       INTO
           v_credits,
           v_debits
       FROM
           gltrans 
       where
           gltrans_date >= v_start
        AND 
           gltrans_date <= v_end
       AND 
           gltrans_accnt_id = v_accnt_id
       AND
           (gltrans_posted)
        AND
            NOT gltrans_deleted;
   
   --- let's do a sanity check...
        IF  ABS(v_pre_beginning - v_beginning ) > 1 THEN
             RAISE NOTICE 'BEGIN (DIFF=%) did not match TID=% %..% %:%  NewB=% / OldB=%  ',
                ABS(v_pre_beginning - v_beginning ) ,
                   i_id, v_yearperiod_start, v_start, v_accnt_id, v_accnt_descrip,
                   
                   v_beginning, v_pre_beginning;
        END IF;
        
        IF   ABS( ABS(v_credits) -  v_pre_credits ) > 1 THEN
            RAISE NOTICE 'CREDIT (DIFF=%) did not match TID=% @%  %:% NC=% / C=%  ',
                    ABS( ABS(v_credits) -  v_pre_credits ) ,
                   i_id, v_start, v_accnt_id, v_accnt_descrip,
                   v_credits, v_pre_credits;
        
        END IF;
        
        IF  ABS(  ABS(v_debits) -   v_pre_debits ) > 1 THEN
            RAISE NOTICE 'DEBIT (DIFF=%) did not match TID=% @% %:% ND=% / D=%  ',
            ABS(  ABS(v_debits) -   v_pre_debits ) ,
                   i_id, v_start, v_accnt_id, v_accnt_descrip,
                    v_debits, v_pre_debits;
        END IF;
        
        IF    ABS( v_pre_ending - (v_beginning + v_credits + v_debits )) > 1 THEN
            RAISE NOTICE 'END (DIFF=%) did not match TID=% @% %:% NC=% / C=%   ND=% / D=%  NB=% / B=%   NE=% / E=% ',
                    ABS( v_pre_ending - (v_beginning + v_credits + v_debits )),
                   i_id, v_start, v_accnt_id, v_accnt_descrip,
                   v_credits, v_pre_credits,
                   v_debits, v_pre_debits,
                   v_beginning, v_pre_beginning,
                   v_beginning + v_credits + v_debits, v_pre_ending;
        END IF;

        IF v_pre_beginning = v_beginning AND ABS(v_credits) =  v_pre_credits  AND ABS(v_debits) =  v_pre_debits AND 
                   v_pre_ending = v_beginning + v_credits + v_debits
                   THEN
                   return false;
        END IF;
      -- RAISE NOTICE 'Fix % % % ', i_id, v_start, v_accnt_descrip;
    
   
  RETURN true;

END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION  trialbal_check(i_id integer)
  OWNER TO admin;        
           
 
CREATE OR REPLACE FUNCTION trialbal_fix(i_id integer)
  RETURNS boolean AS
$BODY$
DECLARE
  
    v_start DATE;
    v_end DATE;
    v_accnt_id INTEGER;
    v_pre_credits NUMERIC;
    v_pre_debits NUMERIC;
    v_pre_beginning NUMERIC;
    v_pre_ending NUMERIC;
    v_beginning NUMERIC;
    v_credits NUMERIC;
    v_debits NUMERIC;
    v_accnt_descrip TEXT;
     v_accnt_type TEXT;
    v_yearperiod_start DATE;
BEGIN
    
   
   SELECT
       period_start,
       period_end,
       trialbal_accnt_id,
       trialbal_credits,
       trialbal_debits,
       trialbal_beginning,
       trialbal_ending,
       accnt_descrip,
       accnt_type,
       yearperiod_start
   INTO
       v_start,
       v_end,
       v_accnt_id,
       v_pre_credits,
       v_pre_debits,
       v_pre_beginning,
       v_pre_ending,
       v_accnt_descrip,
       v_accnt_type,
       v_yearperiod_start
   FROM
       trialbal
   LEFT JOIN
       period
   ON
       period_id = trialbal_period_id
    LEFT JOIN
        yearperiod
    ON
        yearperiod_id = period_yearperiod_id
       
    LEFT JOIN
        accnt
    ON
        accnt_id = trialbal_accnt_id
   WHERE
       trialbal_id = i_id;
       
    IF strpos(v_accnt_descrip, 'Retained Earn') > 0	 THEN
        return false;
    END IF;
    --IF v_accnt_id =  134 THEN -- opening balance has unrecorded transactions!??
    --    return false;
    --END IF;
    --IF i_id =  22395 OR i_id = 17371 or i_id = 17372  OR i_id = 17373 OR i_id = 22396 THEN -- $0.01
    --    return false;
    --END IF;
   
   -- this beginning amount differs depending
   -- on if it's carried forward each year or not..
   
   -- expense : $0 at beginning of financial year..
    
    -- assets start for ever..
    
    if v_accnt_type = 'A' OR v_accnt_type = 'L'  OR v_accnt_type = 'Q'  THEN
         v_yearperiod_start = '1970-01-01'::date; 
    END IF;
   
   
   
   SELECT
       COALESCE(sum(
             ROUND(gltrans_amount,2)
       ),0)
       INTO
           v_beginning
       FROM
           gltrans 
       where
           gltrans_date < v_start
        AND
            gltrans_date >=  v_yearperiod_start
       AND 
           gltrans_accnt_id = v_accnt_id
       AND
           gltrans_posted
        AND
            NOT gltrans_deleted;
   
   
   SELECT
       
       COALESCE(sum(
           CASE WHEN  gltrans_amount > 0 THEN ROUND(gltrans_amount,2) ELSE 0 END 
       ),0) ,
       COALESCE(sum(
           CASE WHEN  gltrans_amount < 0 THEN ROUND(gltrans_amount,2) ELSE 0 END 
       ),0)  
       INTO
           v_credits,
           v_debits
       FROM
           gltrans 
       where
           gltrans_date >= v_start
        AND 
           gltrans_date <= v_end
       AND 
           gltrans_accnt_id = v_accnt_id
       AND
           (gltrans_posted)
        AND
            NOT gltrans_deleted;
   
   --- let's do a sanity check...
        --IF  v_pre_beginning != v_beginning  THEN
        --     RAISE EXCEPTION 'BEGIN did not match TID=% %..% %:%  NewB=% / OldB=%  ',
        --           i_id, v_yearperiod_start, v_start, v_accnt_id, v_accnt_descrip,
        --           
        --           v_beginning, v_pre_beginning;
        --END IF;
        --
        --IF    ABS(v_credits) !=  v_pre_credits  THEN
        --    RAISE EXCEPTION 'CREDIT did not match TID=% @%  %:% NC=% / C=%  ',
        --           i_id, v_start, v_accnt_id, v_accnt_descrip,
        --           v_credits, v_pre_credits;
        --
        --END IF;
        --
        --IF    ABS(v_debits) !=  v_pre_debits  THEN
        --    RAISE EXCEPTION 'DEBIT did not match TID=% @% %:% ND=% / D=%  ',
        --           i_id, v_start, v_accnt_id, v_accnt_descrip,
        --            v_debits, v_pre_debits;
        --END IF;
        --
        --IF    v_pre_ending != v_beginning + v_credits + v_debits  THEN
        --    RAISE EXCEPTION 'END did not match TID=% @% %:% NC=% / C=%   ND=% / D=%  NB=% / B=%   NE=% / E=% ',
        --           i_id, v_start, v_accnt_id, v_accnt_descrip,
        --           v_credits, v_pre_credits,
        --           v_debits, v_pre_debits,
        --           v_beginning, v_pre_beginning,
        --           v_beginning + v_credits + v_debits, v_pre_ending;
        --END IF;

       IF v_pre_beginning = v_beginning AND ABS(v_credits) =  v_pre_credits  AND ABS(v_debits) =  v_pre_debits AND 
                   v_pre_ending = v_beginning + v_credits + v_debits
                   THEN
                   return false;
        END IF;
      -- RAISE NOTICE 'Fix % % % ', i_id, v_start, v_accnt_descrip;
   
   UPDATE trialbal
       SET
           trialbal_beginning = v_beginning,
           trialbal_ending = v_beginning + v_credits + v_debits,
           trialbal_credits = ABS(v_credits),
           trialbal_debits = ABS(v_debits)
       WHERE
           trialbal_id = i_id;
           
           
   
  RETURN true;

END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION  trialbal_fix(i_id integer)
  OWNER TO admin;        
           
SELECT trialbal_check(trialbal_id) FROM ( SELECT trialbal_id FROM trialbal  LEFT JOIN
       period
   ON
       period_id = trialbal_period_id
        WHERE
            period_start > '2007-12-01'
            AND
            trialbal_accnt_id = 149
       ORDER BY period_start ASC
      
       ) x;        
        

      
--SELECT trialbal_fix(trialbal_id) FROM ( SELECT trialbal_id FROM trialbal  LEFT JOIN
--       period
--   ON
--       period_id = trialbal_period_id
--        WHERE period_start > '2012-12-01'
--       ORDER BY period_start ASC
--      
--       ) x;        
--        
        