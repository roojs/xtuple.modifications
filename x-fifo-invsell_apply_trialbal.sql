CREATE OR REPLACE FUNCTION invsell_apply_trialbal (integer) RETURNS integer
AS $BODY$
DECLARE
    i_accnt_id integer;
BEGIN

    UPDATE trialbal t SET
        trialbal_credit = ao_gltrans_credit,
        trialbal_debit  = ao_gltrans_debit,
        trialbal_ending = trialbal_beginning - trialbal_debits + trialbal_credits    
    FROM 
        (
            SELECT 
                a1_period_id ao_period_id, a1_gltrans_credit ao_gltrans_credit, 
                a2_gltrans_debit ao_gltrans_debit
            FROM
                (
                    SELECT period_id a1_period_id, sum(glrans_amount) a1_gltrans_credit 
                    FROM gltrans 
                    JOIN period ON gltrans_date BETWEEN period_start AND period_end
                    WHERE 
                        gltrans_date > v_mininvsell_transdate
                        AND
                        gltrans_amount > 0
                ) a1,
                
                (
                    SELECT period_id a2_period_id, sum(glrans_amount) a2_gltrans_debit 
                    FROM gltrans 
                    JOIN period ON gltrans_date BETWEEN period_start AND period_end
                    WHERE 
                        gltrans_date > v_mininvsell_transdate
                        AND
                        gltrans_amount < 0
                ) a2
            WHERE a1_period_id = a2_perion_id
        ) ao
        
    WHERE 
        trialbal_period_id = ao_period_id
        AND 
        trialbal_accnt_id = i_accnt_id;
        
END
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
  
ALTER FUNCTION  invsell_apply_trialbal(integer)
  OWNER TO admin;
