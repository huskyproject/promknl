#!/usr/bin/make -f
PASOPT = -dLinux

PASFILES = crc32.pas crc.pas generalp.pas inifile.pas log.pas mkdos.pas mkffile.pas mkfile.pas mkglobt.pas mkmisc.pas mkmsgabs.pas mkmsgezy.pas mkmsgfid.pas mkmsghud.pas mkmsgjam.pas mkmsgsqu.pas mkopen.pas mkstring.pas pmknl.pas types.pas

all: debug

pmknl: $(PASFILES)
	ppc386 $(PASOPT) pmknl.pas

debug:
	ppc386 $(PASOPT) -dDEBUG pmknl.pas

release:
	ppc386 $(PASOPT) -dRELEASE pmknl.pas

