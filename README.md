xtuple.modifications
====================

Public changes to xtuple sql schema

Includes:




a) Explode Kit part non-destructive updateing

 - explodekit.sql [MODIFIED]
 - triggers-coitem.sql [MODIFIED]
 - x-dragon-deletesoitemcheck.sql [NEW]

b) Planning credit memo applications to invoices (cobmisc)

 -  x-dragon-cobapply.sql  [NEW]

c) Showing the exact quantity of stock a particular time.
 
  - x-dragon-invdetail-bydate.sql [NEW]

d) planning inventory transfers

  - x-dragon-invhist-transfer.sql [NEW]

e) query optimizations
    
  - x-dragon-optimize.sql  [NEW]
 
f) usefull salesorder based calculations
 
  - x-dragon-salesordercalcs.sql  [NEW]

g) source location and target ship id for planning sales orders and shipments.

  - x-dragon-salesorder-planning.sql  [NEW]

h) netsuite import utilitiy methods / tables.
   Converts ItemReciept grouping into recvgrp and adds oldid columns to some tables
   to make refering easier.
   
  - x-netsuite-recvgrp.sql  [NEW]
  - x-netsuite-mig-extra.sql [NEW]
  
b) void invoice keeps invoice number so it can be reissued with same number. and
   renames old invoice with -x-oldid
  
  - voidinvoice.sql [MODIFIED]