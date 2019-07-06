SET DESTSAS="?sv=2017-11-09&ss=bfqt&srt=sco&sp=rwdlacup&se=2018-11-12T14:23:42Z&st=2018-11-12T06:23:42Z&spr=https&sig=G7VdY1yXAg%%2FJ2N0%%2FMazvDaWj%%2BU4wDDglz8cL9t%%2Fj8E0%%3D"
SET DESTKEY=ZUQx1rSdoLqtL8pev7ixBYyENMgywDRQAAEmuhSRRoK/lH9iaYqRoE8LzukJ9ZzKzyGd10KvSQ8jndbE1/r6HA==
SET SOURCE=%~dp0
SET DEST=https://stac074.blob.core.windows.net/testblob074
SET DEST2=https://stac074.blob.core.windows.net/testcont074

AzCopy /Source:%SOURCE% /Dest:%DEST% /DestSAS:%DESTSAS%  /S /Y
AzCopy /Source:%SOURCE% /Dest:%DEST2% /DestKey:%DESTKEY%  /S /Y
