  
--  extra cols to help migration.
  
ALTER TABLE cobmisc ADD COLUMN cobmisc_oldid INT;

CREATE INDEX cobmisc_oldid_ix
  ON cobmisc
  USING btree
  (cobmisc_oldid);

ALTER TABLE invchead ADD COLUMN invchead_oldid INT;

CREATE INDEX invchead_oldid_ix
  ON invchead
  USING btree
  (invchead_oldid);




-- maps to VendorBill.  
alter table vohead add column vohead_oldid INT DEFAULT 0;
CREATE INDEX vodist_oldid_ix
  ON vodist
  USING btree
  (vodist_orig_id);
  
    
  
ALTER TABLE recv ADD COLUMN recv_oldid TEXT;
CREATE INDEX recv_oldid_ix
  ON recv 
  USING btree
  (recv_oldid);



-- not sure why we did not use oldid here..

alter table vodist add column vodist_orig_id INT DEFAULT 0;
CREATE INDEX vodist_orig_id_ix
  ON vodist
  USING btree
  (vodist_orig_id);
  