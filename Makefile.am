## Makefile.am -- Use bootstrap to process this file.
#
#  Copyright 2008 Geoff Levand
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License, Version 2 as
# published by the Free Software Foundation.
#

composed_mans =

man_MANS = $(composed_mans)

composed_bin_scripts = flac2mp4

bin_SCRIPTS = $(composed_bin_scripts)

composed_files = $(composed_bin_scripts) $(composed_mans)

edit = sed \
	-e 's|@PACKAGE_NAME\@|$(PACKAGE_NAME)|g' \
	-e 's|@PACKAGE_VERSION\@|$(PACKAGE_VERSION)|g' \
	-e 's|@PACKAGE_BUGREPORT\@|$(PACKAGE_BUGREPORT)|g' \
	-e 's|@libexecdir\@|$(libexecdir)|g' \
	-e 's|@datadir\@|$(pkgdatadir)|g' \
	-e 's|@prefix\@|$(prefix)|g'

flac2mp4: Makefile $(srcdir)/flac2mp4.in
	rm -f $@ $@.tmp
	$(edit) $(srcdir)/$@.in >$@.tmp
	chmod +x $@.tmp
	mv $@.tmp $@

EXTRA_DIST = bootstrap configure.ac.in $(addsuffix .in, $(composed_mans))

MAINTAINERCLEANFILES = aclocal.m4 config.* configure configure.ac depcomp \
	install-sh ltmain.sh Makefile.in missing $(PACKAGE)-*.gz

CLEANFILES = $(composed_files) $(addsuffix .tmp, $(composed_files))
