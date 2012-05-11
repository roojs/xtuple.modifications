#!/bin/sh

diff -u -w original/api-functions-insertsalesline.sql   api-functions-insertsalesline.sql > diffs/api-functions-insertsalesline.sql.diff
diff -u -w  original/copyso.sql  copyso.sql > diffs/copyso.sql.diff
diff -u -w  original/distributeitemlocseries.sql distributeitemlocseries.sql > diffs/distributeitemlocseries.sql.diff
diff -u -w  original/distributetolocations.sql distributetolocations.sql > diffs/distributetolocations.sql.diff
diff -u -w original/explodekit.sql explodekit.sql > diffs/explodekit.sql.diff
diff -u -w original/invadjustment.sql invadjustment.sql > diffs/invadjustment.sql.diff
diff -u -w original/invreceipt.sql invreceipt.sql > diffs/invreceipt.sql.diff 
diff -u -w  original/postinvtrans.sql  postinvtrans.sql  > diffs/postinvtrans.sql.diff 
diff -u -w original/relocateinventory.sql relocateinventory.sql > diffs/relocateinventory.sql.diff
diff -u -w original/triggers-coitem.sql triggers-coitem.sql > diffs/triggers-coitem.sql.diff
diff -u -w original/valueatshipping.sql valueatshipping.sql > diffs/valueatshipping.sql.diff

