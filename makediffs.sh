#!/bin/sh

diff -u -w original/explodekit.sql explodekit.sql > diffs/explodekit.sql.diff
diff -u -w original/triggers-coitem.sql triggers-coitem.sql > diffs/triggers-coitem.sql.diff
diff -u -w original/relocateinventory.sql relocateinventory.sql > diffs/relocateinventory.sql.diff
