#!/bin/sh

diff -u -w original/explodekit.sql explodekit.sql > diffs/explodekit.sql.diff
diff -u -w original/triggers-coitem.sql triggers-coitem.sql > diffs/triggers-coitem.sql.diff

