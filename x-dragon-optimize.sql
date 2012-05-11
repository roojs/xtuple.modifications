
-- indexes speed our list up..

CREATE INDEX cohead_orderdate  ON cohead  USING btree  (cohead_orderdate);
  
CREATE INDEX itemloc_locsite  ON itemloc USING btree  (itemloc_itemsite_id, itemloc_location_id);

-- this does not exist??  - what was it supposed to do?
--CREATE INDEX itemsite_costcode_id_key   ON itemsite  USING btree  (itemsite_costcode_id );




  