-- Sequence: cobapply_id_seq

-- DROP SEQUENCE cobapply_id_seq;

CREATE SEQUENCE cobapply_id_seq
  INCREMENT 1
  MINVALUE 1
  MAXVALUE 2147483647
  START 1
  CACHE 1;
ALTER TABLE cobapply_id_seq
  OWNER TO admin;
GRANT ALL ON TABLE cobapply_id_seq TO admin;
GRANT ALL ON TABLE cobapply_id_seq TO xtrole;


-- cob apply - planned credit memo applications for a bill ;


CREATE TABLE cobapply
(
    cobapply_id integer NOT NULL DEFAULT nextval(('cobapply_id_seq'::text)::regclass),
    cobapply_cobmisc_id integer,
    cobapply_aropen_id integer,
    cobapply_applied boolean,
  
    CONSTRAINT cobapply_pkey PRIMARY KEY (cobapply_id ),
    CONSTRAINT cobapply_cobmisc_id_fkey FOREIGN KEY (cobapply_cobmisc_id)
        REFERENCES cobmisc (cobmisc_id) 
      ON UPDATE CASCADE ON DELETE NO ACTION,
    CONSTRAINT cobapply_aropen_id_fkey FOREIGN KEY (cobapply_aropen_id)
        REFERENCES aropen (aropen_id) 
      ON UPDATE CASCADE ON DELETE NO ACTION
)
WITH (
  OIDS=FALSE
);

CREATE INDEX cobapply_cobmisc_id_ix  ON cobapply  USING btree  (cobapply_cobmisc_id);
CREATE INDEX cobapply_aropen_id_ix  ON cobapply  USING btree  (cobapply_aropen_id);
CREATE INDEX cobapply_applied_ix  ON cobapply  USING btree  (cobapply_applied); 

ALTER TABLE cobapply
  OWNER TO admin;
GRANT ALL ON TABLE cobapply TO admin;
GRANT ALL ON TABLE cobapply TO xtrole;
COMMENT ON TABLE cobapply
  IS 'Planned credit memo applies to bills';
  
  