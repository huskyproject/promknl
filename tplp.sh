#!/bin/sh
# $1 = Name der Nodeliste ohne Endung
# $2 = Name der Nodediff ohne Endung bzw. "no-diff", falls
#      keine Diff erstellt wurde (nicht m”glich war zu erstellen)
# $3 = Hunderterstelle der aktuellen Tagesnummer
# $4 = Zehnerstelle der aktuellen Tagesnummer
# $5 = Einerstelle der aktuellen Tagesnummer
# $6 = Hunderterstelle der vorherigen Tagesnummer
# $7 = Zehnerstelle der vorherigen Tagesnummer
# $8 = Einerstelle der vorherigen Tagesnummer

echo $1 $2 $3 $4 $5 $6 $7 $8
# arc2 a $1.a$4$5 $1.$3$4$5
# protick hatch area=test.nodelist file=$1.a$4$5 from=999:999/999@testnet to=999:999/999@testnet origin=999:999/999@testnet replace=tnpnt.* desc=TestNet_PointList_for_day_#$3$4$5
# protick toss

