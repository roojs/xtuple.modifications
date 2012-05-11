--
-- Table to group recv's into


CREATE TABLE recvgrp
(

  recvgrp_id integer NOT NULL DEFAULT nextval(('recvgrp_id_seq'::text)::regclass),
  recvgrp_number text NOT NULL,
  CONSTRAINT recvgrp_pkey PRIMARY KEY (recvgrp_id )
)
WITH (
  OIDS=FALSE
);
ALTER TABLE recvgrp
  OWNER TO admin;
GRANT ALL ON TABLE recvgrp TO admin;
GRANT ALL ON TABLE recvgrp TO xtrole;
COMMENT ON TABLE recvgrp
  IS 'Information about Groups of Received Order Items.';
  
  
CREATE UNIQUE INDEX recvgrp_number_idx
  ON recvgrp 
  USING btree
  (recvgrp_number COLLATE pg_catalog."default" );



CREATE SEQUENCE recvgrp_id_seq
  INCREMENT 1
  MINVALUE 1
  MAXVALUE 2147483647
  START 1
  CACHE 1;
ALTER TABLE recvgrp_id_seq
  OWNER TO admin;
GRANT ALL ON TABLE recvgrp_id_seq TO admin;
GRANT ALL ON TABLE recvgrp_id_seq TO xtrole;

  
  
ALTER TABLE recv ADD COLUMN recv_recvgrp_id INTEGER;

 
CREATE INDEX recv_recvgrp_id_ix  ON recv  USING btree  (recv_recvgrp_id);
 

ALTER TABLE recv ADD CONSTRAINT recv_recvgrp_id_fkey FOREIGN KEY (recv_recvgrp_id)
        REFERENCES recvgrp(recvgrp_id) MATCH SIMPLE
      ON UPDATE CASCADE ON DELETE NO ACTION;
