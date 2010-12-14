# Makefile
#
DATE = $(shell date +%Y%m%d)
PACKAGE = alawiki-$(DATE)
DISTFILES = Makefile .htaccess wiki2html.awk wiki.cgi wiki.css wiki.js
DISTFILES += wikidocs/wiki
DISTFILES += wikidocs/wiki-20[0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9][0-9][0-9]


$(PACKAGE).tgz: $(DISTFILES)
	ln -sfn . $(PACKAGE)
	tar cfz $@ $(addprefix $(PACKAGE)/, $^)
	rm -f $(PACKAGE)

