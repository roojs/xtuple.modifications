create table invbuy (
    invbuy_invhist_id integer NOT NULL UNIQUE,
    invbuy_transdate timestamp with time zone DEFAULT ('now'::text)::timestamp(6) with time zone,
    invbuy_ordnumber text NOT NULL,
    invbuy_itemsite_id integer NOT NULL,
    invbuy_qty numeric(18, 6),
    invbuy_totalcost numeric(12, 2),
    invbuy_unitcost numeric(16, 6),
    invbuy_transtype character(2),
    invbuy_qtyafter numeric(18, 6),
    invbuy_totalcostafter numeric(12, 2),
        
    CONSTRAINT invbuy_pkey PRIMARY KEY (invbuy_itemsite_id, invbuy_ordnumber),
    CONSTRAINT invbuy_invhist_fk FOREIGN KEY (invbuy_invhist_id) REFERENCES invhist (invhist_id),
    CONSTRAINT invbuy_itemsite_fk FOREIGN KEY (invbuy_itemsite_id) REFERENCES itemsite (itemsite_id)
);

CREATE INDEX invbuy_qty_indx
  ON invbuy
  USING btree
  (invbuy_qty);

CREATE INDEX invbuy_qtyafter_indx
  ON invbuy
  USING btree
  (invbuy_qtyafter);

CREATE INDEX invbuy_totalcostafter_indx
  ON invbuy
  USING btree
  (invbuy_totalcostafter);

CREATE INDEX invbuy_transtype_indx
  ON invbuy
  USING btree
  (invbuy_transtype);

CREATE INDEX invbuy_transdate_indx
  ON invbuy
  USING btree
  (invbuy_transdate);    


create table invsell (
    invsell_invhist_id integer NOT NULL UNIQUE,
    invsell_transdate timestamp with time zone DEFAULT ('now'::text)::timestamp(6) with time zone,
    invsell_itemsite_id integer NOT NULL,
    invsell_ordnumber text NOT NULL,
    invsell_qty numeric(18, 6),
    invsell_current_totalcost numeric(12, 2),
    invsell_current_unitcost numeric(16, 6),
    invsell_transtype character(2),
    invsell_qtybefore numeric(18, 6),
    invsell_totalcostbefore numeric(12, 2),
    invsell_calc_unitcost numeric(18, 6),
    invsell_calc_totalcost numeric(18, 6),
    invsell_is_estimate boolean,
        
    CONSTRAINT invsell_pkey PRIMARY KEY (invsell_itemsite_id, invsell_ordnumber),
    CONSTRAINT invsell_invhist_fk FOREIGN KEY (invsell_invhist_id) REFERENCES invhist (invhist_id),
    CONSTRAINT invsell_itemsite_fk FOREIGN KEY (invsell_itemsite_id) REFERENCES itemsite (itemsite_id)
);

CREATE INDEX invsell_qty_indx
  ON invsell
  USING btree
  (invsell_qty);

CREATE INDEX invsell_qtyafter_indx
  ON invsell
  USING btree
  (invsell_qtyafter);

CREATE INDEX invsell_totalcostafter_indx
  ON invsell
  USING btree
  (invsell_totalcostafter);

CREATE INDEX invsell_transtype_indx
  ON invsell
  USING btree
  (invsell_transtype);

CREATE INDEX invsell_transdate_indx
  ON invsell
  USING btree
  (invsell_transdate);    

CREATE TABLE invdepend (
    invdepend_parent_id integer NOT NULL,
    invdepend_invhist_id integer NOT NULL,
    
    CONSTRAINT invdepend_pkey PRIMARY KEY (invdepend_parent_id),
    CONSTRAINT invdepend_parent_fk FOREIGN KEY (invdepend_parent_id) REFERENCES invhist (invhist_id),
    CONSTRAINT invdepend_invhist_fk FOREIGN KEY (invdepend_invhist_id) REFERENCES invhist (invhist_id)
);


