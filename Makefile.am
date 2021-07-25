AUTOMAKE_OPTIONS = foreign

ACLOCAL_AMFLAGS = -I m4

composed_bin_scripts = \
	scripts/check-vfat-names.sh \
	scripts/flac-add-tracktotal.sh \
	scripts/flac-clean-tags.sh \
	scripts/flac-meta-rename.sh \
	scripts/flac-print-tags.sh \
	scripts/flac-tag-switcher.sh \
	scripts/flac-write-tags.sh \
	scripts/audx-lib.sh \
	scripts/m4a-converter.sh \
	scripts/make-age-list.sh \
	scripts/make-inventory.sh \
	scripts/make-playlists.sh \
	scripts/make-shufflelist.sh \
	scripts/rip-c-flac-tags.sh \
	scripts/rip-c.sh \
	scripts/rip-c-to-flac.sh

bin_SCRIPTS = $(composed_bin_scripts)

nobase_bin_SCRIPTS = 

edit = sed \
	-e 's|@PACKAGE\@|$(PACKAGE)|g' \
	-e 's|@PACKAGE_BUGREPORT\@|$(PACKAGE_BUGREPORT)|g' \
	-e 's|@PACKAGE_NAME\@|$(PACKAGE_NAME)|g' \
	-e 's|@PACKAGE_URL\@|$(PACKAGE_URL)|g' \
	-e 's|@PACKAGE_VERSION\@|$(PACKAGE_VERSION)|g' \
	-e 's|@datadir\@|$(pkgdatadir)|g' \
	-e 's|@libexecdir\@|$(libexecdir)|g' \
	-e 's|@prefix\@|$(prefix)|g'

$(composed_bin_scripts): % : Makefile $(srcdir)/%.in
	rm -f $@ $@.tmp
	mkdir -p $$(dirname $@)
	$(edit) $(srcdir)/$@.in > $@.tmp
	chmod +x $@.tmp
	mv $@.tmp $@

EXTRA_DIST = bootstrap configure.ac COPYING m4 mit-plus-license.txt README.md \
	version.sh $(addsuffix .in, $(composed_bin_scripts)) \
	$(nobase_bin_SCRIPTS)

CLEANFILES = $(bin_SCRIPTS)

MAINTAINERCLEANFILES = aclocal.m4 compile config.h* configure depcomp \
 install-sh Makefile.in missing $(PACKAGE)-*.gz

maintainer-clean-local:
	rm -rf m4 .deps

.PHONY: help

help:
	@echo "Targets:"
	@echo "  make install"
	@echo "  make dist"
	@echo "  make distcheck"
	@echo "  make distclean"
	@echo "  make maintainer-clean"
