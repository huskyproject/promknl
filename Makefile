#!/usr/bin/make -f

# include Husky-Makefile-Config
include ../huskymak.cfg

ifeq ($(DEBUG), 1)
  POPT = -d$(OSTYPE) -Fu$(INCDIR) -dDEBUG
else
  POPT = -d$(OSTYPE) -Fu$(INCDIR) -dRELEASE
endif

PASFILES = crc32.pas crc.pas generalp.pas inifile2.pas log.pas mkdos.pas mkffile.pas mkfile.pas mkglobt.pas mkmisc.pas mkmsgabs.pas mkmsgezy.pas mkmsgfid.pas mkmsghud.pas mkmsgjam.pas mkmsgsqu.pas mkopen.pas mkstring.pas pmknl.pas types.pas

all: pmknl$(EXE)

pmknl$(EXE): $(PASFILES)
	$(PC) $(POPT) pmknl.pas

clean:
	-$(RM) $(RMOPT) *$(OBJ)
	-$(RM) $(RMOPT) *$(TPU)
	-$(RM) $(RMOPT) *~

distclean: clean
	-$(RM) $(RMOPT) pmknl$(EXE)

install:
	$(INSTALL) $(IBOPT) pmknl$(EXE) $(BINDIR)

uninstall:
	-$(RM) $(RMOPT) $(BINDIR)$(DIRSEP)pmknl$(EXE)

