
-- we use target date as a proxy for ship date in planning stuff.  
ALTER TABLE cohead ADD COLUMN cohead_targetdate DATE;
CREATE INDEX cohead_targetdate  ON cohead   USING btree  (cohead_targetdate);  


-- store intended source in coitem and default in cohead - can be null..
ALTER TABLE coitem ADD COLUMN coitem_location_src INTEGER DEFAULT NULL;
ALTER TABLE coitem ADD CONSTRAINT coitem_location_src
        FOREIGN KEY ( coitem_location_src ) REFERENCES location (location_id)
        MATCH SIMPLE;
        

-- store intended destination on (defaults to matching cohead..)
ALTER TABLE coitem ADD COLUMN coitem_shipto_id INTEGER DEFAULT NULL;
ALTER TABLE coitem ADD CONSTRAINT coitem_shipto_id
        FOREIGN KEY ( coitem_shipto_id )  REFERENCES shiptoinfo(shipto_id)
        MATCH SIMPLE;
        
        
        
ALTER TABLE cohead ADD COLUMN cohead_location_src INTEGER;
ALTER TABLE cohead ADD CONSTRAINT cohead_location_src
        FOREIGN KEY ( cohead_location_src ) REFERENCES location (location_id)
        MATCH SIMPLE;


-- changes to ship head so they ship per locations..


ALTER TABLE shiphead ADD COLUMN shiphead_location_id INT;
ALTER TABLE shiphead ADD CONSTRAINT shiphead_location_id
        FOREIGN KEY ( shiphead_location_id ) REFERENCES location (location_id)
        MATCH SIMPLE;
        
        
ALTER TABLE shiphead ADD COLUMN shiphead_shipto_id INT;
ALTER TABLE shiphead ADD CONSTRAINT shiphead_shipto_id
        FOREIGN KEY ( shiphead_shipto_id )  REFERENCES shiptoinfo(shipto_id)
        MATCH SIMPLE;
        

CREATE INDEX shiphead_shipto_id_ix  ON shiphead   USING btree  (shiphead_shipto_id);
CREATE INDEX shiphead_location_id_ix  ON shiphead   USING btree  (shiphead_location_id);  

   
  