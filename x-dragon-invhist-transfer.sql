-- Sequence: accnt_accnt_id_seq

-- DROP SEQUENCE accnt_accnt_id_seq;

CREATE SEQUENCE invhist_transfer_id_seq
  INCREMENT 1
  MINVALUE 1
  MAXVALUE 2147483647
  START 1
  CACHE 1;
ALTER TABLE invhist_transfer_id_seq
  OWNER TO admin;
GRANT ALL ON TABLE invhist_transfer_id_seq TO admin;
GRANT ALL ON TABLE invhist_transfer_id_seq TO xtrole;


CREATE TABLE invhist_transfer
(
  invhist_transfer_id integer NOT NULL DEFAULT nextval(('invhist_transfer_id_seq'::text)::regclass),
  invhist_transfer_transdate  timestamp with time zone DEFAULT ('now'::text)::timestamp(6) with time zone,
  invhist_transfer_number text,
  invhist_transfer_from integer,
  invhist_transfer_to integer,
  invhist_transfer_descrip text,
  
     CONSTRAINT invhist_transfer_pkey PRIMARY KEY (invhist_transfer_id ),
    CONSTRAINT invhist_transfer_to_fkey FOREIGN KEY (invhist_transfer_to)
        REFERENCES location (location_id) 
      ON UPDATE CASCADE ON DELETE NO ACTION,
    CONSTRAINT invhist_transfer_from_fkey FOREIGN KEY (invhist_transfer_from)
      REFERENCES location (location_id)  
      ON UPDATE CASCADE ON DELETE NO ACTION
)
WITH (
  OIDS=FALSE
);

CREATE INDEX invhist_transfer_number_ix  ON invhist_transfer  USING btree  (invhist_transfer_number);
CREATE INDEX invhist_transfer_transdate_ix  ON invhist_transfer  USING btree  (invhist_transfer_transdate );
CREATE INDEX invhist_transfer_loc_ix  ON invhist_transfer  USING btree  (invhist_transfer_from, invhist_transfer_to );

ALTER TABLE invhist_transfer ADD COLUMN invhist_transfer_posted BOOLEAN DEFAULT false;

CREATE INDEX invhist_transfer_posted_ix  ON invhist_transfer  USING btree  (invhist_transfer_posted );
 

ALTER TABLE invhist_transfer
  OWNER TO admin;
GRANT ALL ON TABLE invhist_transfer TO admin;
GRANT ALL ON TABLE invhist_transfer TO xtrole;
COMMENT ON TABLE invhist_transfer
  IS 'Inventory Transfer Group';
  
  
  
CREATE TRIGGER invhist_transfertrigger
  BEFORE INSERT OR UPDATE OR DELETE
  ON invhist_transfer
  FOR EACH ROW
  EXECUTE PROCEDURE _invhist_transfertrigger();
  
  
  

CREATE OR REPLACE FUNCTION _invhist_transfertrigger()
  RETURNS trigger AS
$BODY$
DECLARE
  

BEGIN
    IF (TG_OP = 'INSERT') THEN
        IF (NEW.invhist_transfer_posted) THEN 
            RAISE EXCEPTION 'You can not create a transfer which is already posted';
        END IF;
        RETURN NEW;
    END IF;
    
    IF (TG_OP = 'DELETE') THEN
        IF (OLD.invhist_transfer_posted) THEN 
            RAISE EXCEPTION 'You can not delete a transfer which is already posted';
        END IF;
        RETURN OLD;
    END IF;
    
    -- we are now updating
    
    
    IF (OLD.invhist_transfer_posted) THEN
        IF (
            ( OLD.invhist_transfer_transdate != NEW.invhist_transfer_transdate ) OR
            ( OLD.invhist_transfer_number != NEW.invhist_transfer_number ) OR
            ( OLD.invhist_transfer_from !=  NEW.invhist_transfer_from) OR
            ( OLD.invhist_transfer_to != NEW.invhist_transfer_to ) 
        ) THEN
            RAISE EXCEPTION 'You can not modify a transfer which is already posted';
        END IF;
        RETURN NEW;
    END IF;
    
    -- if it's not posted..
    RETURN NEW;
    
 END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION _invhist_transfertrigger()
  OWNER TO admin;  
    




--     ------------------------------- 

    

CREATE SEQUENCE invhist_transfer_item_id_seq
  INCREMENT 1
  MINVALUE 1
  MAXVALUE 2147483647
  START 1
  CACHE 1;
ALTER TABLE invhist_transfer_item_id_seq
  OWNER TO admin;
GRANT ALL ON TABLE invhist_transfer_item_id_seq TO admin;
GRANT ALL ON TABLE invhist_transfer_item_id_seq TO xtrole;


CREATE TABLE invhist_transfer_item
(
  invhist_transfer_item_id integer NOT NULL DEFAULT nextval(('invhist_transfer_item_id_seq'::text)::regclass),
  invhist_transfer_item_invhist_transfer_id integer NOT NULL,
  invhist_transfer_item_itemsite_id integer NOT NULL,
  invhist_transfer_item_qty integer,
  
   CONSTRAINT invhist_transfer_item_pkey PRIMARY KEY (invhist_transfer_item_id ),
   CONSTRAINT invhist_transfer_item_itemsite_fkey FOREIGN KEY (invhist_transfer_item_itemsite_id)
        REFERENCES itemsite (itemsite_id) 
      ON UPDATE CASCADE ON DELETE NO ACTION,
    CONSTRAINT invhist_transfer_item_invhist_transfer_fkey FOREIGN KEY (invhist_transfer_item_invhist_transfer_id)
        REFERENCES invhist_transfer ( invhist_transfer_id) 
      ON UPDATE CASCADE ON DELETE NO ACTION
)
WITH (
  OIDS=FALSE
);


ALTER TABLE invhist_transfer_item ADD COLUMN invhist_transfer_item_line INTEGER;
ALTER TABLE invhist_transfer_item ADD COLUMN invhist_transfer_invhist_id  INTEGER;

CREATE INDEX invhist_transfer_item_line_ix  ON invhist_transfer_item  USING btree  (invhist_transfer_item_line);
 

ALTER TABLE invhist_transfer_item ADD CONSTRAINT invhist_transfer_invhist_fkey FOREIGN KEY (invhist_transfer_invhist_id)
        REFERENCES invhist(invhist_id) MATCH SIMPLE
      ON UPDATE CASCADE ON DELETE NO ACTION;


ALTER TABLE invhist_transfer_item
  OWNER TO admin;
GRANT ALL ON TABLE invhist_transfer_item TO admin;
GRANT ALL ON TABLE invhist_transfer_item TO xtrole;
COMMENT ON TABLE invhist_transfer_item
  IS 'Inventory Transfer Group Item';
  
  
  
  
CREATE TRIGGER invhist_transfer_itemtrigger
  BEFORE INSERT OR UPDATE OR DELETE
  ON invhist_transfer_item
  FOR EACH ROW
  EXECUTE PROCEDURE _invhist_transfer_itemtrigger();
  
  
  

CREATE OR REPLACE FUNCTION _invhist_transfer_itemtrigger()
  RETURNS trigger AS
$BODY$
DECLARE
   _p RECORD;

BEGIN
     
    IF (TG_OP = 'UPDATE') THEN
        IF (OLD.invhist_transfer_item_invhist_transfer_id != NEW.invhist_transfer_item_invhist_transfer_id) THEN
            RAISE EXCEPTION 'You can not modify then transfer group of transfer item ';
        END IF;
    END IF;
    
    
    IF ((TG_OP = 'INSERT') OR (TG_OP = 'UPDATE')) THEN
        
        SELECT * FROM invhist_transfer INTO  _p  WHERE
                invhist_transfer_id = NEW.invhist_transfer_item_invhist_transfer_id
                LIMIT 1;
        
    END IF;
    IF (TG_OP = 'DELETE') THEN        
        SELECT * FROM invhist_transfer INTO  _p  WHERE
                invhist_transfer_id = OLD.invhist_transfer_item_invhist_transfer_id
                LIMIT 1;
        
    END IF;
    
    
    
    IF (_p.invhist_transfer_posted) THEN 
        RAISE EXCEPTION 'You can not modify records of a transfer that is already posted';
    END IF;
    
    
    IF (TG_OP = 'DELETE') THEN
        RETURN OLD;
    END IF;
    
    RETURN NEW;  
    
 END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION _invhist_transfer_itemtrigger()
  OWNER TO admin;  
  
  
  

-- create dummy itemlocs

CREATE OR REPLACE FUNCTION itemloc_get(int, int)
  RETURNS  int  AS
$BODY$
DECLARE
  
  i_itemsite ALIAS FOR $1;
  i_location ALIAS FOR $2;
  v_id int;
   
BEGIN
    SELECT itemloc_id INTO v_id FROM itemloc WHERE
        itemloc_itemsite_id = i_itemsite
        AND 
        itemloc_location_id = i_location;
        
        
    IF (NOT FOUND) THEN
        INSERT INTO itemloc ( 
            itemloc_itemsite_id , itemloc_location_id ,
            itemloc_qty, itemloc_expiration  ,
            itemloc_consolflag
        ) VALUES (
            i_itemsite, i_location,
            0, endoftime(),
            false
        );
        SELECT itemloc_id INTO v_id FROM itemloc WHERE
            itemloc_itemsite_id = i_itemsite
            AND 
            itemloc_location_id = i_location;
            
    END IF;


   RETURN v_id;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION  itemloc_get(int,int)
  OWNER TO admin;


  
--- post the invhist_Transfer...


CREATE OR REPLACE FUNCTION invhist_transfer_post(int)
  RETURNS  int  AS
$BODY$
DECLARE
  i_id ALIAS FOR $1;
  v_location_from  INTEGER;
  v_location_to INTEGER;
  v_transdate timestamp with time zone;
  v_number TEXT;
  
  v_return INTEGER;
  
  _r RECORD;
   
BEGIN
    v_return := 0;

    


   SELECT
         
        invhist_transfer_from ,
        invhist_transfer_to,
        invhist_transfer_transdate ,
        invhist_transfer_number  
        
        INTO
         v_location_from, 
        v_location_to ,
        v_transdate,
        v_number
         FROM
            invhist_transfer
         WHERE
            invhist_transfer_id = i_id
            AND
            invhist_transfer_posted = false
          LIMIT 1;
   

    IF (NOT FOUND) THEN
        RAISE EXCEPTION 'Unposted Stock transfer does not exist';
        RETURN -1;
    END IF;

--# when transactions are the same day, we only want to include the ones with lower ids..
    FOR _r IN  SELECT  relocateInventory(
                itemloc_get( invhist_transfer_item_itemsite_id, v_location_from),
                 v_location_to,
                invhist_transfer_item_itemsite_id,
                invhist_transfer_item_qty,
                v_number,
                v_transdate
                
                ) AS result
                FROM
                    invhist_transfer_item
                WHERE
                     invhist_transfer_item_invhist_transfer_id = i_id
    
        LOOP       
            IF _r.result < 1 THEN
                RAISE EXCEPTION 'Failed to Post Stock transfer';
                RETURN -1;
            END IF;
            
    END LOOP;

    UPDATE invhist_transfer SET invhist_transfer_posted = true WHERE 
        invhist_transfer_id = i_id;

  RETURN v_return;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION  invhist_transfer_post(int)
  OWNER TO admin;



  
CREATE OR REPLACE FUNCTION invhist_transfer_void(int)
  RETURNS  int  AS
$BODY$
DECLARE
  i_id ALIAS FOR $1;
  v_location_from  INTEGER;
  v_location_to INTEGER;
  v_transdate timestamp with time zone;
  v_number TEXT;
  
  v_return INTEGER;
  v_itemloc_id INTEGER;
  _r RECORD;
   
BEGIN
    v_return := 0;

    


   SELECT
         
        invhist_transfer_from ,
        invhist_transfer_to,
        invhist_transfer_transdate ,
        invhist_transfer_number  
        
        INTO
         v_location_from, 
        v_location_to ,
        v_transdate,
        v_number
         FROM
            invhist_transfer
         WHERE
            invhist_transfer_id = i_id
            AND
            invhist_transfer_posted = true
          LIMIT 1;
   

    IF (NOT FOUND) THEN
        RAISE EXCEPTION 'Posted Stock transfer does not exist';
        RETURN -1;
    END IF;
    
    
     
    
--# when transactions are the same day, we only want to include the ones with lower ids..
-- to and from are reversed..
    FOR _r IN  SELECT  relocateInventory(
                itemloc_get( invhist_transfer_item_itemsite_id, v_location_to),
                v_location_from,
                invhist_transfer_item_itemsite_id,
                invhist_transfer_item_qty ,
                v_number || ' REVERSED',
                v_transdate
                ) AS result
                FROM
                    invhist_transfer_item
                WHERE
                     invhist_transfer_item_invhist_transfer_id = i_id
    
        LOOP       
            IF _r.result < 1 THEN
                RAISE EXCEPTION 'Failed to Post Stock transfer';
                RETURN -1;
            END IF;
            
    END LOOP;

    UPDATE invhist_transfer SET invhist_transfer_posted = false WHERE 
        invhist_transfer_id = i_id;

  RETURN v_return;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION  invhist_transfer_void(int)
  OWNER TO admin;

