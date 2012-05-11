xtuple.modifications
====================

Public changes to xtuple sql schema

Includes:

a) Explode Kit part non-destructive updateing

MODIFIED

 - explodekit.sql
 - triggers-coitem.sql

NEW
 
 - x-dragon-deletesoitemcheck.sql

b) Planning credit memo applications to invoices (cobmisc)

 -  x-dragon-cobapply.sql  

c) Showing the exact quantity of stock a particular time.
 
  - x-dragon-invdetail-bydate.sql

d) planning inventory transfers

  - x-dragon-invhist-transfer.sql

e) query optimizations
    
    - x-dragon-optimize.sql 

f) usefull salesorder based calculations
 
    - x-dragon-salesordercalcs.sql 

g) source location and target ship id for planning sales orders and shipments.

    - x-dragon-salesorder-planning.sql 

h) netsuite import utilitiy methods / tables.
   Converts ItemReciept grouping into recvgrp and adds oldid columns to some tables
   to make refering easier.
   
  - x-netsuite-recvgrp.sql 
  - x-netsuite-mig-extra.sql 