#! /usr/bin/gawk -f
#
# Copyright (c) 2009 - 2010 Christian W. Moenneckes
#
# vim:sts=4:ts=8

BEGIN {
    IGNORECASE = 1;
   
    # Attention:
    OPT["IMG_DIR"]     = "/var/www/icons";
    OPT["IMG_URL"]     = "/icons";

    OPT["DEFAULT_DOC"] = "toc";
    OPT["USE_SYMLINK"] = 1;
    OPT["MAX_DEBUG"]   = 2;
    OPT["ALLOW_EDIT"]  = 1;
    OPT["TMP_PREFIX"]  = "/tmp/wiki-draft-";
    OPT["PROC_UPTIME"] = "/proc/uptime";

    OPT["EXTERNAL_IMG"] = 1;

    OPT["MAX_INTERNALLINK_LENGTH"] = 64;
   
    OPT["INDENT"] = 4;
#    OPT["ICON"]   = "/project.new/validator/html.cgi?" rand();

    # 1: for edit 
    # 2: for edit & view source
    # 3: for edit & view source & view draft 
    OPT["LOGIN"] = 0;

    OPT["DRAFT_VIEW"]  = 1;

    OPT["SITE_DIR"] = ".";
    OPT["SITE_URL"] = "..";
    
    for (var in OPT)
	if (ENVIRON[var]) OPT[var] = ENVIRON[var];

    OPT["DOC_DIR"]     = OPT["SITE_DIR"] "/wikidocs";
    OPT["META_DIR"]    = OPT["SITE_DIR"] "/meta";

    OPT["UPLOAD_DIR"] = OPT["SITE_DIR"] "/uploads";
    OPT["UPLOAD_URL"] = OPT["SITE_URL"] "/uploads";
    OPT["THUMB_DIR"]  = OPT["SITE_DIR"] "/thumbs";
    OPT["THUMB_URL"]  = OPT["SITE_URL"] "/thumbs";

    HAVE_DOC[""] = "";
#    DOC_EXISTS[0] = 0;

    if (ENVIRON["SERVER_NAME"] == "dual.c-w-m.loc")
        OPT["HTML_CHECK"] = "<a href='/dyna/validator-0.8.5/htdocs/check?uri=referer' class='etool'>valid HTML:<img src='/project.new/validator/html.cgi' alt='' style='border:0px'></a>" \
     " <a href='http://jigsaw.w3.org/css-validator/check/referer' class='etool'>validate CSS</a>";
    else
        OPT["HTML_CHECK"] = "<a href='http://validator.w3.org/check?uri=referer' class='etool'>validate HTML</a>" \
     " <a href='http://jigsaw.w3.org/css-validator/check/referer' class='etool'>validate CSS</a>";
 

#    OPT["HTML_CHECK"] = "<a href='/dyna/validator-0.8.5/htdocs/check?uri=referer' class='etool'>validate HTML</a>" \
 #    " <a href='http://jigsaw.w3.org/css-validator/check/referer' class='etool'>validate CSS</a>";

    REGEX_HTML["INLINE"] = "^(a|b|code|em|i|span|strong|tt)$";
    REGEX_HTML["LIST"]   = "^(dl|ol|ul)$";
    REGEX_HTML["ITEM"]   = "^(li|dd|dt)$";

    CHAR2LIST["*"] = "ul"; CHAR2ITEM["*"] = "li";
    CHAR2LIST["#"] = "ol"; CHAR2ITEM["#"] = "li";
    CHAR2LIST[";"] = "dl"; CHAR2ITEM[";"] = "dt";
    CHAR2LIST[":"] = "dl"; CHAR2ITEM[":"] = "dd";

    UPTIME = uptime();
    
    TABLE = 0;
    CREOLE_TABLE = 0;
    HEADING_LEVEL = 0;
    DT_WORD = "";
    PART = "HEAD";
    
    TAG[0] = 0;      # HTML tag stack
    TAG_IDENT[0] = 0;
    IN_TAG[0] = 0;   # HTML tag counter
    HTML_ID[0] = 0;
    LAST_TAG = "";
    
    RAW = "";
    SELF = "";
    RW = 0;

    REF[0] = 0;
    ELINKS[0] = 0; # FIXME !?!
    TOC[0] = 0;

    KEYWORDS[0] = 0;
    KEYVALUE[0] = 0;
   
#    FILE2TYPE ;
    DOC = "";
    
    DST_FILE = "";
    SRC_FILE = "";

    CGI[0] = 0;

    EXIT = 0;
    CGI["debug"] = 0;

    if (ENVIRON["SERVER_PROTOCOL"] ~ /^HTTP/) {

	OPT["DOC_DIR"] = abs_path(OPT["DOC_DIR"]);
	OPT["META_DIR"] = abs_path(OPT["META_DIR"]);
	OPT["IMG_DIR"] = abs_path(OPT["IMG_DIR"]);
	OPT["UPLOAD_DIR"] = abs_path(OPT["UPLOAD_DIR"]);
	OPT["THUMB_DIR"] = abs_path(OPT["THUMB_DIR"]);
	
	SELF = ((ENVIRON["HTTPS"] ~ /^on$/i) ? "https://" : "http://") \
		ENVIRON["SERVER_NAME"] ENVIRON["SCRIPT_NAME"];
	if (ENVIRON["REQUEST_METHOD"] == "POST") {
	    query= "";
	    if (ENVIRON["CONTENT_TYPE"] ~ /^multipart\/form-data/) {
		getline boundary;
		gsub(/\r/, "", boundary);
		while (line != boundary "--\r") {
		    var = "";
		    while (getline line && line != "\r") {
			gsub(/\r/, "", line);
#			printf "GET a head: %s\n", line >> "/dev/stderr";
			if (match(line, /^Content-Disposition:.*\<name=["']([^"']+)["']/, ary)) {
			    printf "^ VAR :%s\n", ary[1];
			    var = ary[1];
			}
		    }
		    while (getline line && \
			   line != boundary "\r" && \
			   line != boundary "--\r") {
#			printf "GET a data for '%s'\n", var >> "/dev/stderr";
			if (var) CGI[var] = CGI[var] line "\n";
		    }
		    if (var) sub(/\r\n$/, "", CGI[var]);
		}
		if (line != boundary "--\r")
		    errstr = sprintf("upload error '%s'", boundary);
		else {
		    if ((CGI["file"] = is_docname(CGI["file"])) && \
			CGI["upload"] && OPT["UPLOAD_DIR"] \
			) {
			if (f_readable(OPT["UPLOAD_DIR"] "/" CGI["file"])>=0) {
			    errstr = sprintf("sorry, file %s already exists" \
				, CGI["file"] \
				);
			} else {
			    printf "%s", CGI["upload"] \
			       > OPT["UPLOAD_DIR"] "/" CGI["file"];

			    if (0) 
			    errstr = sprintf("%d  bytes in %s written" \
				, length(CGI["upload"]) \
				, CGI["file"] \
				);
			}
		    } else {
		        errstr = sprintf("uploaded %d %d %d bytes" \
			    , length(CGI["pre"]) \
			    , length(CGI["upload"]) \
			    , length(CGI["post"]) \
			    );
		    }
		}
	    } else {
	        getline query; # < ("/dev/stdin");
	    }
	} else if (ENVIRON["REQUEST_METHOD"] == "GET") {
	    query = ENVIRON["QUERY_STRING"];
	} else {
	    errstr = sprintf("unknown method '%s'",ENVIRON["REQUEST_METHOD"]); 
	}

	ary[0] = split(query, ary, /&/);
	for (i = 1; i <= ary[0]; i ++) {
	    if (match(ary[i], /^([a-z]+)=([^=]*)/,a)) 
	        CGI[a[1]] = gensub(/\r/, "", "g", decode(a[2]));
	}

        if (CGI["debug"] > OPT["MAX_DEBUG"]) CGI["debug"] = OPT["MAX_DEBUG"];
    
	if (! ENVIRON["PATH_INFO"]) {
	    printf "Location: %s/%s\n\n", SELF, OPT["DEFAULT_DOC"];
	    exit(EXIT = 1);
	} else if (CGI["doc"]) {
	    while (match(CGI["doc"], /^(.*)[ _]+([A-Z].*)/,ary))
		CGI["doc"] = ary[1] ary[2];
		   
	    printf "Location: %s/%s\n\n", SELF, CGI["doc"];
	    #printf "Location: %s/%s?mode=edit\n\n", SELF, CGI["new"];
	    exit(EXIT = 1);
#	} else if (match(ENVIRON["PATH_INFO"], /^\/([a-zA-Z0-9_-]+)$/, ary) \
	} else if (substr(ENVIRON["PATH_INFO"], 1, 1) == "/" \
	    && (DOCNAME = is_docname(substr(ENVIRON["PATH_INFO"], 2))) \
	    ) {
	    ARGC =1;
	    #DOC = gensub(/_/, " ", "g", DOCNAME = ary[1]);
	    DOC = gensub(/_/, " ", "g", DOCNAME);

	    if (CGI["mode"] == "login") {
		#&& (! ENVIRON["AUTH_TYPE"] || ! ENVIRON["REMOTE_USER"])) {
		if (OPT["LOGIN"] && ! ENVIRON["REMOTE_USER"]) {
		    printf "Status: 401 Authorization Required\n";
		    printf "WWW-Authenticate: Basic realm='Wiki write access'\n";
		}
#		printf "Content-Type: text/html; charset=iso-8859-1\n\n";
#		printf "<html><body>nix authent</body></html>\n";
#		exit(EXIT = 2);
		CGI["mode"] = "";
	    }

	    SRC_FILE = OPT["DOC_DIR"] "/" DOCNAME;

	    if (OPT["DRAFT_VIEW"]) {
		draftfile = SRC_FILE ".draft";
	    } else {
		if (CGI["mode"] ~ /^(draft|edit-draft|diff-draft)$/)
		    CGI["mode"] = "";

		draftfile = OPT["TMP_PREFIX"] DOCNAME;
	    }
	    
	    if (OPT["ALLOW_EDIT"])
		RW = ! ( (OPT["USE_SYMLINK"]) \
		       ?  system("test -L " SRC_FILE " -a -w " OPT["DOC_DIR"]) \
		       :  system("test -w " SRC_FILE) \
		       );

	    # FIXME: allow create docs ?
	    if ((stat = f_readable(SRC_FILE)) < 0) {
		SRC_FILE = "";
		if (OPT["ALLOW_EDIT"]) RW = 2; 
		if (CGI["mode"] == "edit" && ! CGI["txt"]) {
		    CGI["txt"] = sprintf("= %s =\n", DOC);
		    CGI["mode"] = "preview";
		}
	    }

	    if (OPT["LOGIN"] && ! ENVIRON["REMOTE_USER"]) {
		RW = 0;
		if (OPT["LOGIN"] >= 2 && \
		    CGI["mode"] ~ /^(source|edit-draft|diff-draft)$/)
		    CGI["mode"] = "";
		  
		if (OPT["LOGIN"] >= 3 && CGI["mode"] == "draft")
		    CGI["mode"] = "";
	    }
	    
	    if (! RW && (  CGI["mode"] == "save" \
			|| CGI["mode"] == "preview" \
		        || CGI["mode"] == "diff-edit" \
			|| CGI["mode"] == "edit" \
			|| CGI["mode"] == "edit-draft" \
			|| CGI["mode"] == "discard" \
			)) CGI["mode"] = "";

	    if (CGI["mode"] ~ /^(save|discard)$/) {
#		printf "zeroing %s\n", draftfile >> "/dev/stderr";
		printf "" > draftfile;
		close(draftfile);
		if (CGI["mode"] == "discard") {
		    printf "Location: %s/%s\n\n", SELF, DOCNAME;
		    exit(EXIT = 3);
		}
		savefile = OPT["DOC_DIR"] "/" DOCNAME;
		if (OPT["USE_SYMLINK"])
		    if(system(sprintf("ln -sfn %s%s %s" \
		       , DOCNAME, strftime("-%Y%m%d-%H%M%S"), savefile)))
			errstr = "can't create symlink";
	    } else if (  CGI["mode"] == "preview" \
		     ||  CGI["mode"] == "diff-edit" \
		    ) {
		DST_FILE = savefile = draftfile; # for diff
	    } else {
		viewfile = SRC_FILE;

		if (OPT["DRAFT_VIEW"] && f_readable(draftfile) > 0) {
		    DST_FILE = draftfile; # for diff

		    if (CGI["mode"] == "draft") {
			viewfile = DST_FILE;
		    } else if (CGI["mode"] == "edit-draft") {
			viewfile = DST_FILE;
			CGI["mode"] = "edit";
		    }
		} else if (CGI["mode"] ~ /^(draft|edit-draft)$/)
		    CGI["mode"] = "";
		
		FILE2TYPE[ ARGV[ARGC++] = viewfile ] = "DOC";
		if (0) {
		    metafile = OPT["META_DIR"] "/" DOCNAME;
		    if (! CGI["mode"] && f_readable(metafile) > 0)
			ARGV[ARGC++] = metafile;
		}
	    }
	    
	    if (savefile) {
#		printf "writing %s\n", savefile >> "/dev/stderr";
		printf "%s", CGI["txt"] > savefile;
		close(savefile);
		if (CGI["mode"] == "save") {
		    for (meta in CGI) {
			if (!CGI[meta] || meta !~ /^meta/) continue;
			check_meta(substr(meta, 5), CGI[meta], DOCNAME, 1);
		    }
			
		    printf "Location: %s/%s\n\n", SELF, DOCNAME;
		    exit(EXIT = 4);
		}
		FILE2TYPE[ ARGV[ARGC++] = savefile ] = "DOC";;
	    } 
	} else if (ENVIRON["PATH_INFO"] == "/") {
	    DOC = "Sitemap";
	} else {
	    errstr = sprintf("Invalid document: %s\n",ENVIRON["PATH_INFO"]);
	}
	
	printf "Content-Type: text/html\n\n";
	if (CGI["mode"] ~ /^(cancel|save)$/) CGI["mode"] = "";
    }
#    print "<!DOCTYPE html PUBLIC '-//W3C//DTD HTML 4.01 Transitional//EN' 'http://www.w3.org/TR/html4/loose.dtd'>";
    print "<!DOCTYPE html PUBLIC '-//W3C//DTD HTML 4.01//EN' 'http://www.w3.org/TR/html4/strict.dtd'>";
    html_tag("html");
    html_tag("head");
    html_tag("title", "", raw2html(((CGI["mode"]) ? "" CGI["mode"] ":" : " ") DOC,1));

    html_tag("meta", "http-equiv='Content-type' content='text/html;charset=UTF-8'");

    if (CGI["refresh"] && ! CGI["mode"])
	html_tag("meta", "http-equiv='refresh' content='7'");

    html_tag("link", sprintf("rel='stylesheet' media='screen' type='text/css' href='%s/wiki.css'", OPT["SITE_URL"]));

    if (OPT["ICON"])
	html_tag("link", "rel='icon' type='image/png' href='" OPT["ICON"] "'");

    html_tag("script", sprintf("src='%s/wiki.js' type='text/javascript'", OPT["SITE_URL"]), " ");
    
#    html_close("head");
    html_tag("body");
    if (errstr) {
	html_tag("p", "class='error'", errstr);
	exit(EXIT = 0);
    }
    if (CGI["debug"] >= 2) {
	html_tag("pre");
        printf "ARGC=%s\nARGIND=%s\n",ARGC,ARGIND;
	
	printf "PROCINFO\n"
	for (v in PROCINFO) print raw2html(" " v " " PROCINFO[v], 1);

	printf "ENVIRON\n"
	for (v in ENVIRON) print raw2html(" " v "=" ENVIRON[v], 1);
	
	printf "CGI\n"
	for (v in CGI) print raw2html(" " v "=" CGI[v], 1);

	printf "OPT\n"
	for (v in OPT) print raw2html(" " v "=" OPT[v], 1);

	html_close("pre");
    }
    
    if (CGI["mode"] == "diff-edit" || CGI["mode"] == "diff-draft") {
	if (! DST_FILE || ! SRC_FILE) {
	    printf "nix file (src=%s dst=%s)", SRC_FILE, DST_FILE;
	    CGI["mode"] = "";
	    exit(EXIT = 0);
	}
	cmd = "LANG=C diff -uw " SRC_FILE " " DST_FILE;

	html_tag("table");
	line = 0;
	src_row[0] = 0;
	src_ptr = 1;
	src_start = 0;
	html_tag("tr");
	html_tag("th", "colspan='2'", "current version");
	html_tag("th", "colspan='2'", "draft version");
	html_close("tr");
	while (( cmd | getline) > 0) {
	    if (++line <= 2) {
		;
	    } else if ($0 !~ /^[ \+\-]/) {
	        html_tag("tr");

		if (match($0, /^@@ -([0-9]+),([0-9]+) \+([0-9]+),([0-9]+) @@/, ary)) {
		    src_start = ary[1];
		    dst_start = ary[3];

		    html_tag("td", "colspan='4' align='center'", "...");
		} else {
		    html_tag("td", "colspan='4' align='center'" \
			     , "<code>"$0"</code>");
		}
	        html_close("tr");
		if ($0 !~ /^\\/) {
	            src_row[0] = 0;
		    src_ptr = 1;
		}
	    } else {
		code = raw2html(substr($0, 2), 1);
		if ((c = substr($0, 1, 1)) == "-") {
		    src_row[++src_row[0]] = code;
		} else {
		    dst_class = (c == "+") ? "diff_in" : "";
		    html_tag("tr");
		    if (src_ptr <= src_row[0]) {
			first = src_ptr;
			last = (c == " ") ? src_row[0] : src_ptr;
			while(src_ptr <= last) {
			    diff_html(src_start ++,src_row[src_ptr++]\
				, (c == "+") ? "diff_mod" : "diff_out");
#			    if (last != first) {
			    if (c != "+") {
				html_tag("td", "colspan='2'", " ");
				html_close("tr");
				html_tag("tr");
			    }
			}
			if (c == "+") dst_class = "diff_mod";
		    } else if (c == "+") {
			html_tag("td", "colspan='2'", " ");
		    } 
		    if (c == " ") diff_html(src_start ++, code);
		    diff_html(dst_start ++, code, dst_class);
		    html_close("tr");
		}
	    }
	}
	close(cmd);
    
	if (src_ptr <= src_row[0]) {
	    while(src_ptr <= src_row[0]) {
		html_tag("tr");
		diff_html(src_start ++,src_row[src_ptr++],  "diff_out");
		html_tag("td", "colspan='2'", " ");
		html_close("tr");
	    }
	} else if (c != "+") {
	    html_tag("tr");
	    html_tag("td", "colspan='4' align='center'", "...");
	    html_close("tr");
	}
	
	html_close("table");
	exit(EXIT = 0);
    }
    PART = "DOC";
}

function self(mode, link) {
    if (! link) link = "?mode=" mode;
    if (CGI["mode"] == mode)
        html_tag("a", "href='" link "' class='tool_on'", mode);
    else
        html_tag("a", "href='" link "' class='tool'", mode);
}

function node(u,ary,up,l, i, ary2,a) {
    a = 0;
#    ary2[a] = 0;
    for (i = 1; i <= ary[0]; i++)
	if (up[ary[i]] == u) ary2[a++] = ary[i];
    asort(ary2);
#    ary2[0] = a;
    for (a = 1; a <= ary2[a]; a ++) {
	i = ary_index(ary, ary2[a]);
	if (! ary[i]) continue;
	if (l) 
            list_wiki2html(str_repeat(";", l));
	else if (a == 1) 
	    printf "[ ";
	else 
	    printf " | ";
	printf "%s", a_href(ary[i]);
        if (l) node(i, ary, up, l+1);
    }
    if (! l && a >= 1) printf " ]";
}
function count_meta(u,ary,up, i,c) {
    c = 0;
    for (i = 1; i <= ary[0]; i++)
        if (up[ary[i]] == u) c ++;
    return c;
}
function show_meta(meta, val, ary,up,key,i,u,file) {
    if (! is_docname(meta)) return;
    ary[0] = 0;
    up[0]  = 0;
    file = OPT["META_DIR"] "/" meta;
    while ((getline < (file)) > 0) {
        if (substr($0, 1, 1) == ";") {
	    u = ary_index(ary, key = trim(substr($0, 2)));
	    if (u > ary[0]) {
	        ary[ary[0] = u] = key;
	        up[key] = 0;
	    }
	} else if (substr($0, 1, 1) == ":") {
	    i = ary_index(ary, key = trim(substr($0, 2)));
	    if (i > ary[0]) ary[ary[0] = i] = key;
	    up[key] = u;
	}
    }
    close(file);
    if (val) {
	if (count_meta(u = ary_index(ary, DOCNAME), ary, up)) {
#	    html_head(0, val "/" DOCNAME);
	    html_head(HEADING_LEVEL = 2, "Overview");
	    node(u, ary, up, 2);
	}
	if (val == DOCNAME) return;
	
	if (count_meta(u = ary_index(ary, val), ary, up) <= 1) return;
#	html_tag("-");
	html_tag("p");
	html_head(0, meta "/" val ": ");
	node(u, ary, up, 0);
	html_close("p");
    } else {
	if (count_meta(0, ary, up))
	    html_head(HEADING_LEVEL = 2, meta " Overview");
	node(0, ary, up, 2);
    }
}
END {
    if (EXIT) exit(EXIT);
    
    if (! DOCNAME) html_head(1, DOC);
    PART = "REF";

    if (REF[0] && TAG[0]) {
	html_head(2, "References");
	html_tag("ol"); # ul
	for (i = 1; i <= REF[0]; i ++) {
	    html_tag("li");
	    html_tag("a" \
		, sprintf("href='#ref_%d' name='_ref_%d' class='ref'", i, i) \
		, "&uarr;" \
		);
	    text2html(REF[i]);
	    html_close("li");
	}
	html_close("ol");
    } else {
	html_tag("-"); # close the last tag
    }

    PART = "META";

    if (! CGI["mode"] || 1) {
	html_tag("hr");
	html_tag("div", "style='font-size:10px'");

	show_meta(DOCNAME, "");

      if (1) {	
	cmd = "ls -1 " OPT["META_DIR"] "/[a-z0-9A-Z]*[a-z0-9A-Z]";
	while (( cmd | getline) > 0) {
	    if (! match($0, /[^\/]+$/)) continue;
	    meta = substr($0, RSTART);
	    if (! KEYVALUE[meta])
		show_meta(meta, DOCNAME);
	}
	close(cmd);
      } else {
	if (! KEYVALUE["Category"])
	    show_meta("Category", DOCNAME);
      }
        for (meta in KEYVALUE) {
	    if (! KEYVALUE[meta]) continue;
	    show_meta(meta, KEYVALUE[meta]);
#	if (! check_meta(meta, KEYVALUE[meta], DOC, 0)) {
#	    show_meta(meta, DOCNAME);
	}
        if (ENVIRON["SERVER_PROTOCOL"] ~ /^HTTP/) {
	    ary[0] = split("http://www.google.de/search?q=" \
			 " http://de.wikipedia.org/wiki/" \
			 " http://en.wikipedia.org/wiki/" \
			 , ary);
	
	    html_tag("p");
	    html_head(0, "Search '"DOC"': ");
	    
	    for (i = 1; i <= ary[0]; i++)
		if (match(ary[i], /^https?:\/\/(www\.)?([^\/]+)/, a))
		    printf "%s%s", (i == 1) ? "[ " : " | " \
			, a_href(ary[i] DOC, a[2]);
	    printf " ]";
	    html_close("p");
	}
	    
 #   printf "%s\n", a_href("" DOC);
#    printf "%s\n", a_href(" DOC);

	html_tag("-");
	html_close("div");
    }
    if (TOC[0] > 1) { # && ! CGI["mode"]) {
	html_tag("div", "class='toc' id='TOC' onmouseover='toc(this, 1);' onmouseout='toc(this, 0);'");
	html_via_js("<div style='text-align:right'>[<a href='javascript:toc_close();'>-</a>]</div>");
	for (i = 1; i <= TOC[0]; i++) {
	    list_wiki2html(str_repeat("*", TOC[i,0]), "class='toc'");
	    html_tag("a", "href='#" TOC[i,1] "' class='toc'", TOC[i,2]);
#	    printf("<a %s", TOC[i,1]);
	}
	html_tag("-");
	html_close("div");
	html_tag("div", "class='toc' id='TOC_CLOSED' style='text-align:right;visibility:hidden' onmouseover='toc(this, 1);' onmouseout='toc(this, 0);'");
	html_via_js("[<a href='javascript:toc_open();'>+</a>]");
	html_close("div");
    }
    
    PART = "FOOT";
    
    if (ENVIRON["SERVER_PROTOCOL"] ~ /^HTTP/ && TAG[0]) {
	if (LAST_TAG != "hr") html_tag("hr");

	if (RW && (CGI["mode"] == "edit" \
		|| CGI["mode"] == "preview" \
		|| CGI["mode"] == "diff-edit" \
		)) {
	    if (CGI["mode"] == "edit") {
		CGI["txt"] = RAW;
		CGI["mode"] = "preview";
	    }
	    html_tag("a", "name='edit'", " ");
	    html_tag("form", sprintf("method='POST' action='%s%s'" \
		    , ENVIRON["SCRIPT_NAME"] \
		    , ENVIRON["PATH_INFO"] \
		    ));
txt = CGI["txt"];
	    gsub(/\&/, "\\&amp;",txt);
	    printf "\n<textarea style='width:100%' rows='25' name='txt'>%s</textarea>",txt;
	    html_tag("div", "style='width:100%;' class='tool'");
	    ary[0] = split("preview save cancel",ary);
	    if (OPT["DRAFT_VIEW"]) ary[++ary[0]] = "discard";
	    if (SRC_FILE) ary[++ary[0]] = "diff-edit";
	    for (i = 1; i <= ary[0]; i ++)
		if (ary[i] == CGI["mode"]) # || ary[i] == "preview")
		    printf "<input type='submit' name='mode' value='%s' class='tool_on'>", ary[i];
		else
		    printf "<input type='submit' name='mode' value='%s' class='tool'>", ary[i];
	    if (OPT["LOGIN"])
		printf "User: %s\n", ENVIRON["REMOTE_USER"];
	    
	    html_close("div");
	    html_tag("hr"); 
	    for (meta in KEYVALUE) {
	        if (! KEYVALUE[meta]) continue;
		if (! check_meta(meta, KEYVALUE[meta], DOC, 0)) {
		    html_tag("input", "type='hidden' name='meta"meta"' value='"KEYVALUE[meta]"'");
		}
	    }
	    html_close("form");
	} else {
	    html_tag("form", sprintf("method='POST' action='%s%s'" \
		    , ENVIRON["SCRIPT_NAME"] \
		    , ENVIRON["PATH_INFO"] \
		    ));

	    html_tag("div", "style='width:100%' class='tool'");
	    html_tag("a", "href='" SELF "' class='tool'", "home");
	    html_tag("a", "href='" SELF "/' class='tool'", "sitemap");
#	    html_tag("a", "href='?' class='tool'", "reload");
	    self("page", "?");
	    if (SRC_FILE && (OPT["LOGIN"] <= 2 || ENVIRON["REMOTE_USER"]))
		self("source");
	    
	    if (DST_FILE && OPT["DRAFT_VIEW"]) {
		self("draft");
		if (SRC_FILE) self("diff-draft");
		if (RW) self("edit-draft", "?mode=edit-draft#edit");
	    } else if (RW) {
	        self("edit", "?mode=edit#edit");
	    }
	    html_tag("input", "type='text' name='doc' value='"CGI["doc"]"'");
	    html_tag("input", "type='submit' value='go' class='tool'");

	    if (OPT["LOGIN"]) {
		if (ENVIRON["REMOTE_USER"])
		    printf "User: %s\n", ENVIRON["REMOTE_USER"];
		else
		    html_tag("a", "href='?mode=login' class='tool'", "login");
	    }
	    if (OPT["HTML_CHECK"]) print OPT["HTML_CHECK"];
	    html_close("div");
	    html_close("form");
	}

	if (LAST_TAG != "hr") html_tag("hr");

	if (1 && ! CGI["mode"] && KEYWORDS[0]) {
	    for (meta in KEYVALUE) {
		if (! KEYVALUE[meta]) continue;
#		print "read .. %s  ..\n", meta;
		check_meta(meta, KEYVALUE[meta], DOCNAME, 0);
	    }
	}

	if (UPTIME) {
#	    html_tag("hr");
	    html_tag("div", "", sprintf("<i>%s (-%.2fs)</i>" \
	       , strftime("%A %F %T %Z") \
	       , uptime() - UPTIME \
	       ));
	}
    }
    
    html_close("body");
    html_close("html");
}
# FIXME: only tested width linux
function uptime () {
    if (OPT["PROC_UPTIME"] && (getline < (OPT["PROC_UPTIME"])) > 0) {
	close(OPT["PROC_UPTIME"]);
	return $1;
#	return gensub(/\./, "", "", $1);
    }
}
function diff_html (row, text, class) {
    html_tag("th", (class = "class='" class "'") " align='right'", row);
    html_tag("td", class, "<code>" text "</code>");
}
function f_readable (file, c, save) {
    if (file ~ /^\/dev\/std(out|err)/) return 0;
    save = $0;
#    if (file ~ /[\/\?\*]/) exit; # FIXME ?
    c = getline < (file);
    close(file);
    $0 = save;
    return c;
}
function abs_path (file, ary) {
    return (file !~ /^\// \
	&& match(ENVIRON["SCRIPT_FILENAME"], /^(.*\/)([^\/]+)$/, ary)) \
	? ary[1] file : file;
}
#
function decode(str,  i) {
    i = 1;
    gsub(/\+/, " ", str)
    while (match(substr(str, i), /(%[0-9a-fA-F][0-9a-fA-F])/)) {
	i += RSTART-1;
	str = substr(str,1, i-1) \
	    sprintf("%c", strtonum("0x" substr(str,i+1 , RLENGTH -1))) \
	    substr(str, i +RLENGTH);
    }
    return str;
}
function html_debug(str) {
    if (CGI["debug"]) printf "<!-- %s -->", str;
}
function html_warn(str) {
    printf "<span class='error'>%s line %s: %s</span><br>", FILENAME, FNR, str;
}
function html_close(tag, i, t) {
    if (TAG[0] <= 0) return html_warn("no more html tags to close");

    t = TAG[0];
    if (tag) 
	while (t > 0 && TAG[t] != tag) {
	    if (t != TAG[0]) html_warn("tag " TAG[t] " not open");
	    t --;
	}

    # close after newline ?
    if (TAG_IDENT[TAG[0]]) {
	html_debug("closing tag");
	printf "\n%s", str_repeat(" ", (TAG[0]-1) * OPT["INDENT"]);
    }
   
    while (TAG[0] >= t) {
	if (TAG[0] > t) html_warn("closing tag " TAG[TAG[0]] " to close " tag);
	if (TAG[--TAG[0]+1] != "-") printf "</%s>", TAG[TAG[0]+1];
    }
}
function html_tag(tag,attr,html,  i,br) {

    if (TAG[0] > 0) {
#    printf "\n<!-- new tag %s statck: ", tag;
 #   for (i = 1; i <= TAG[0]; i ++)
#	printf " %s", TAG[i];
 #   printf "-->";
	# .. keep <pre> & <table> in lists
	if (tag !~ /^(pre|table|)$/ && \
	    tag !~ REGEX_HTML["INLINE"] && \
	    tag !~ REGEX_HTML["LIST"] && \
	    tag !~ REGEX_HTML["ITEM"] ) {
	    # list item still open ?
	    if (TAG[TAG[0]] ~ REGEX_HTML["ITEM"]) html_close();
	    # list still open ?
	    while (TAG[0] > 0 && TAG[TAG[0]] ~ REGEX_HTML["LIST"]) {
		html_close();
		# close parent item in nested list
		if (TAG[0] > 0 && TAG[TAG[0]] ~ REGEX_HTML["ITEM"])
		    html_close(); 
	    }
	}
 
	if (tag == "body") {
	    if (TAG[TAG[0]] == "head")  html_close();
	} else if (tag == "tr") {
	    if (TAG[TAG[0]] == tag)
		return 0;
	    else if (TAG[TAG[0]] ~ /^(pre)$/) 
		html_close();
	    if (TAG[0] > 0 && TAG[TAG[0]] ~ /^(td|th)$/)
		html_close();

	    if (TAG[0] > 0 && TAG[TAG[0]] == "tr")
		html_close();
	} else if (tag ~ /^(td|th)$/) {
	    if (TAG[TAG[0]] ~ /^(pre)$/)
		html_close();
	    if (TAG[TAG[0]] ~ /^(td|th)$/)
		html_close();
	    if (TAG[TAG[0]] != "tr")
		html_tag("tr");
	} else if (tag == "a" && TAG[TAG[0]] == tag) {
	    html_close();
	} else if (tag == "p") {
	html_debug("p: last lala" TAG[TAG[0]]);
	    if (TAG[TAG[0]] ~ /^(p|td)$/) { # ignore <p> in <p> & <td>
		html_debug("next line from same tag"); 
		printf " ";
		return 0;
	    } else 
		while (TAG[TAG[0]] ~ /^(pre|table)$/ \
		       || TAG[TAG[0]] ~ REGEX_HTML["ITEM"] \
		       || "X" TAG[TAG[0]] ~ REGEX_HTML["LIST"] \
		       )
		html_close();
	} else if (tag ~ /^(|-|h[1-6]|hr)$/) {
	    if (TAG[TAG[0]] == tag) { # keep tag open
		html_debug("next line from same tag"); 
		return 0;
	    } else
	   	while (TAG[TAG[0]] ~ /^(p|pre|table)$/ \
		       || TAG[TAG[0]] ~ REGEX_HTML["ITEM"] \
		       || "X" TAG[TAG[0]] ~ REGEX_HTML["LIST"] \
		       )
		html_close();
	# no recursive tags
	#} else if (tag ~ /^(|-|h[1-6]|hr|p|pre|table)$/) {
	} else if (tag ~ /^(div|pre|table)$/) {
	    if (TAG[TAG[0]] == tag) { # keep tag open
		html_debug("next line from same tag"); 
		return 0;
	    # tags welche sich gegenseitig ausschliessen
	    } else if (TAG[TAG[0]] ~ /^(hr|h[1-6]|p|pre|table)$/) 
		html_close();
	# lists
	} else if (tag ~ REGEX_HTML["LIST"]) {
	    if (TAG[TAG[0]] ~ /^(p|pre|table|tr)$/) 
		html_close();
	# list items
	} else if (tag ~ REGEX_HTML["ITEM"]) {
	    if (TAG[TAG[0]] ~ /^(p|pre|table|tr)$/ ||\
		TAG[TAG[0]] ~ REGEX_HTML["ITEM"]) 
		html_close();
        }
    }
    if (tag == "" || tag == "-") return 0;

    html_debug("new tag");

    if (br = (tag ~ REGEX_HTML["INLINE"]) ? "" : "\n") {
#    if (br = (tag ~ REGEX_HTML["INLINE"] && tag != "a") ? "" : "\n") {
	printf "%s%s", br, str_repeat(" ", TAG[0] * OPT["INDENT"]);
#	i = TAG[0] * OPT["INDENT"];
#	while (i -- > 0) printf " ";
    }

    IN_TAG[LAST_TAG = tag] ++;
    if (attr = trim(attr)) 
	attr = " " attr;
    else if (tag == "tr")
	attr = " class='" ((IN_TAG[tag] % 2) ? "even" : "odd") "'";

    if (TAG[0] && br) TAG_IDENT[TAG[0]] ++;
    if (tag !~ /^(br|hr|img|input|link|meta)$/) {
	TAG[++TAG[0]] = tag;
	TAG_IDENT[TAG[0]] = 0;
    }
    
    printf "<%s%s>%s", tag, attr, html;
    
    if (html && TAG[TAG[0]] == tag)
	printf "</%s>" , TAG[TAG[0]--];
#    printf "<!-- tag %s open-->", tag;
    return 1;
}
function html_via_js(html) {
    html_tag("script", "type='text/javascript'" \
	, "<!-- document.write(\"" raw2html(html,1) "\"); // -->" \
	);
}
function str_repeat(str,count, ret,i) {
    ret = "";
    i = 0;
    while (++i <= count) ret = ret str;
    return ret;
}
function ary_index(ary, element, i) {
    i = 1;
    while (i <= ary[0] && ary[i] != element) i++;
    return i;
}
function ary_u_add(ary, element, i) {
#    if (! element) return 0;
    ary[i = ary_index(ary, element)] = element;
    if (ary[0] < i) ary[0] = i;
    return i;
}
function detect_align(text,  lspaces, rspaces) {
    if (! trim(text)) return "";
    lspaces = length(text) - length(gensub(/^ +/, "", "g", text));
    rspaces = length(text) - length(gensub(/ +$/, "", "g", text));

    if (rspaces > 1 && lspaces > 1) 
	return "center";
    else if (rspaces > 0 && lspaces == 0) # rspaces > lspaces) 
	return "left";
    else if (lspaces > 0 && rspaces == 0) #lspaces > rspaces) 
	return "right";
    else if (text ~ /^[[:space:]]*[0-9]+[0-9,':]*([.:][0-9]+)?([[:space:]]+.*|)$/)
	return "right";

}
function raw2html(str, full) {
    # FIXME: dirty
    gsub(/\&/, "\\&amp;", str);
    gsub(/(\&amp;)amp;/, "\\&amp;" str); # restore '&amp;'

    gsub(/(\xc4|\xc3\x84)/, "\\&Auml;", str);
    gsub(/(\xe4|\xc3\xa4)/, "\\&auml;", str);
    gsub(/(\xd6|\xc3\x96)/, "\\&Ouml;", str);
    gsub(/(\xf6|\xc3\xb6)/, "\\&ouml;", str);
    gsub(/(\xdc|\xc3\x9c)/, "\\&Uuml;", str);
    gsub(/(\xfc|\xc3\xbc)/, "\\&uuml;", str);
    gsub(/(\xdf|\xc3\x9f)/, "\\&szlig;", str);
    gsub(/(\xa4|\xe2\x82\xac)/, "\\&euro;", str);

    if (full) {
        gsub(/</, "\\&lt;", str);
	gsub(/>/, "\\&gt;", str);
    }
    return str;
}
function rindex(str, find, i) {
    i = length(str) - length(find) +1;
    while (i > 0 && substr(str, i, length(find)) != find) i --;
    return (i > 0) ? i : 0;
}
function is_word(text) {
    text = trim(text);
    return (text ~ /^[A-Za-z0-9_]+$/) ? text : "";
}
function check_meta(meta,key,val,save, file, a) {
    if (! is_docname(meta) || ! OPT["META_DIR"]) return;
    file = OPT["META_DIR"] "/" meta;
    while ((getline < (file)) > 0) {
	a["b"] = "";
	if (substr($0, 1, 1) == ";") {
	    if (a["key"] && a["key"] == key && val) {
		a["buffer"] = a["buffer"] sprintf("<i>%s</i>\n", ":" val);
		val = "";
	    }
	    a["key"] = trim(substr($0, 2));
	    if (a["key"] == key) a["b"] = "b";
	} else if (substr($0, 1, 1) == ":") {
	    a["val"] = trim(substr($0, 2));
	    if (a["key"] == key && a["val"] && a["val"] == val) {
		a["b"] = "b";
	        val = "";
	    }
	} else if (a["key"] && a["key"] == key && val) {
	    a["buffer"] = a["buffer"] sprintf("<i>%s</i>\n", ":" val);
	    val = "";
	}
	a["buffer"] = a["buffer"] ((a["b"]) ? "<b>" $0 "</b>" : $0) "\n";
    }
    if (val) {
	if (a["key"] != key)
	    a["buffer"] = a["buffer"] sprintf("\n<i>%s</i>\n", ";" key);
	a["buffer"] = a["buffer"] sprintf("<i>%s</i>\n", ":" val);
    }
    close(file);

    if ((val = (a["buffer"] ~ /\<i\>/)) && ! save) {
#	    printf "= <b>%s</b> =\n", meta;
	    gsub(/<i>/, "<i class='diff_in'>", a["buffer"]);
	    gsub(/<b>/, "<b class='diff_mod'>", a["buffer"]);
	    html_head(h2, "Metadata: "meta);
	    html_tag("pre");
	    printf "%s\n", a["buffer"];
	    html_close("pre");
    }

    if (val && save) {
        gsub(/<[^>]*>/, "", a["buffer"]);
	printf "%s", a["buffer"] > file;
	close(file);
    }
    return (val) ? 0 : 1;
}
function formating(str \
	, wiki2html, found, tags, d,s, dst_tag, dst_pos, src_tag, src_pos) {
    
    # creole linebreak
    gsub(/\\\\/, "<br>", str);
    
    if (str !~ /[\*\/'][\*\/']/) return str; # speed hack

    wiki2html["**"] = "strong";
    wiki2html["//"] = "em";

    wiki2html["''"] = "i";
    wiki2html["'''"] = "b";

#    tags[0] = split("''' '' ** //", tags); # ary order in awk ?
    found = 1;
#    loops =0;
    while (found) {
	found = 0;
        for (dst_tag in wiki2html) {
#	for (d = 1; d <= tags[0]; d++) {
#	    dst_tag = tags[d];
	    if (! (dst_pos = rindex(str, dst_tag))) continue;
	    if (dst_tag == "//" && dst_pos > 1 && substr(str,dst_pos -1,1) == ":")
		continue;
#printf "found in %s dst '%s' at %d in {%s}\n", NR, wiki2html[dst_tag], dst_pos, str > "/dev/stderr";

	    while (dst_pos > 1 && substr(str, dst_pos -1, length(dst_tag)) == dst_tag) dst_pos --;
	    src_pos = dst_pos; 
#	    while (src_pos > 0 && substr(str, src_pos, length(dst_tag)) == dst_tag) src_pos --;
	    found = 0;
	    while (! found && --src_pos > 0) {
		for (src_tag in wiki2html) {
		    if (dst_tag == "'''" && src_tag != dst_tag) continue;
#		for (s = 1; s <= tags[0]; s++) {
#		    src_tag = tags[s];
#printf "check %s src {%s} at %d in {%s}\n", NR, src_tag, src_pos, str > "/dev/stderr";
#		    loops ++;
		    if (substr(str, src_pos, length(src_tag)) == src_tag && \
			    (  src_tag != "//" \
		            || src_pos <= 1 \
			    || substr(str, src_pos -1, 1) != ":" \
			    )) {
			found = 1;
			break;
		    }
		}
	    }
	    if (found && src_tag == dst_tag) {
		found = str;
		str = substr(str, 1, src_pos -1) \
		    "<" wiki2html[src_tag] ">" \
		    substr(str, src_pos + length(src_tag), dst_pos - src_pos- length(src_tag)) \
		    "</" wiki2html[dst_tag] ">" \
		    substr(str, dst_pos + length(dst_tag));
#printf "replace in %s tag '%s' from {%s} to {%s}\n", NR, wiki2html[src_tag], found, str > "/dev/stderr";
	    } else {
		found = 0;
	    }
	}
    }
#    str = str "(loops: " loops ")"; 
    return str;
}
function have_doc(str, doc) {
    if (doc = is_docname(trim(str, 4))) { # new docs in CamelCase
	if (HAVE_DOC[doc]) return HAVE_DOC[doc];
	if (f_readable(OPT["DOC_DIR"] "/" doc) > 0) return HAVE_DOC[doc] = doc;
    }
    if (doc = is_docname(trim(str, 3))) { # old docs with_underscore
	if (HAVE_DOC[doc]) return HAVE_DOC[doc];
	if (f_readable(OPT["DOC_DIR"] "/" doc) > 0) return HAVE_DOC[doc] = doc;
    }
#    return HAVE_DOC[doc];
}
function is_docname(str) {
    return ( ( (trim(str, 3) == str) || (trim(str, 4) == str) ) \
	  && length(str) >= 1 \
	  && length(str) <= OPT["MAX_INTERNALLINK_LENGTH"] \
	   ) ? str : "";
}
function a_href(link,html, class, d) {
    if (link ~ /^#/) {
	if (! html) html = substr(link, 2);
        link = "#" gensub(/ /, "_", "g", substr(link, 2));
        class = "local";
    } else if (link ~ /^[^\/]+$/) { # internal
        if (! html) html = link;
	if (link == DOCNAME) 
	    class = "current";
	else if (d = have_doc(link)) {
	    link = d;
	    class = "intern";
	} else {
	    link = trim(link, 4);
	    class = "intern_missing";
	}
    } else {
        if (! html) html = link;
        class = "extern";
    }
    return sprintf("<a href='%s' class='%s'>%s</a>", link, class, html);
}
function add_toc(level,text, u) {
    # 0 level
    # 1 unique name
    # 2 text
    TOC[++TOC[0],0]= level;
    TOC[TOC[0],2] = text;
    return TOC[TOC[0],1] = unique_name(text);
    return sprintf("<a name='%s' id='%s' href='#%s' class='head'>%s</a>",TOC[TOC[0],1] = u = unique_name(text), u, u, raw2html(text,1));
}
function html_head(level,text, u) {
    u = sprintf("<a name='%s' id='%s' href='#%s' class='head'>%s</a>" \
	    , u = add_toc(((level) ? level : HEADING_LEVEL+1), text) \
	    , u, u, raw2html(text, 1) \
	    );

    if (level)	
        html_tag("h" level, "class='" PART "'", u);
    else
	printf "%s", u;
}

#
function img_key(location) {
    if (OPT["UPLOAD_DIR"] && f_readable(OPT["UPLOAD_DIR"] "/" location) > 0)
	return "UPLOAD";
    else if (OPT["IMG_DIR"] && f_readable(OPT["IMG_DIR"] "/" location) > 0)
	return "IMG";
    else
	return "";
}
function img(prefix, location, title, ary,  img_url, img_file) {
    if (ary["attr"] !~ /alt=/) ary["attr"] = ary["attr"] " alt='" title "'";
    if (ary["x"]) ary["attr"] = ary["attr"] " width='" ary["x"] "'";
    if (ary["y"]) ary["attr"] = ary["attr"] " height='" ary["y"] "'";

    if (ary["attr"] ~ /^[^[[:space:]]/) ary["attr"] = " " ary["attr"];
    
    if (title) title = " title='" title "'";
    if (location ~ /^(.+:\/\/)/) {
	if (! prefix && OPT["EXTERNAL_IMG"]) { # Creole external image
	    return sprintf("<img src='%s'%s>", location, ary["attr"], title);
	} else {
	    return sprintf("<a href='%s' class='extern'%s>%s</a>" \
		    , (ary["link"]) ? ary["link"] : location, title, location);
	}
    } else if (! index("/" location "/", "/../")) {
	if (img_url = img_key(location)) {
	    # generate thumn ?
	    if (location !~ /\// \
		    && (ary["x"] || ary["y"]) && OPT["THUMB_DIR"]) {
		ary["geo"] = ary["x"] "x" ary["y"];
		ary["thumb"] =  ary["geo"] "-" location;
		img_file = OPT[img_url "_DIR"] "/" location;
		img_url = OPT["THUMB_URL"] "/" ary["thumb"];
		
		if (f_readable(OPT["THUMB_DIR"] "/" ary["thumb"]) < 0)
		    system("convert -resize " ary["geo"] \
			" " img_file \
			" " OPT["THUMB_DIR"] "/" ary["thumb"] \
			);
	    } else
		img_url = OPT[img_url "_URL"] "/" location;

	    if (ary["link"]) {
		return a_href(ary["link"], sprintf( "<img src='%s'%s>" \
			         , img_url,  ary["attr"] title));
	    } else {
		return sprintf("<img src='%s'%s>", img_url, ary["attr"] title);
	    }
	} else if (OPT["UPLOAD_DIR"] && ! ary["link"]) {

	    if (CGI["upload"] == location) 
		return sprintf("<div><form method='POST' action='%s%s' enctype='multipart/form-data'><p><input type='hidden' name='file' value='%s'><input name='upload' type='file'><input type='submit' value='upload'></p></form></div>" \
		    , ENVIRON["SCRIPT_NAME"] \
		    , ENVIRON["PATH_INFO"] \
		    , location \
		    );
	    else
		return sprintf("<a href='%s' class='intern_missing'%s>%s</a>" \
		    , "?upload=" location \
		    , title, location \
		    );
	}
    }
    return sprintf("<a href='%s' class='intern_missing'%s>%s%s</a>" \
		, ((ary["link"]) ? ary["link"] : OPT["UPLOAD_URL"] "/" location) \
		, title, prefix, location);
}
# MediaWiki image attributes
function mw_img(location, opts,  ary, a, title, ary2, css) {
    ary[0] = split(opts, ary, /\|/);
    title = css = "";
    ary["link"] = "0";
    ary["x"] = ary["y"] = ary["frame"] = ary["attr"] = "";
    for (a = 1; a <= ary[0]; a ++) {
	# Image format
	if (ary[a] == "border") {
	    ary["attr"] = ary["attr"] " class='bordered'";
	} else if (ary[a] == "frame") {
	    ary["frame"] = "frame"; #padding:5px";
	} else if (ary[a] ~ /^(thumb|frameless)$/) {
	    ary["frame"] = ary[a]; #"thumb";
	# 
	} else if (match(ary[a], /^([0-9]+)x([0-9]+)px$/, ary2)) {
	    ary["x"] = ary2[1];
	    ary["y"] = ary2[2];
	} else if (match(ary[a], /^([0-9]+)px$/, ary2)) {
	    ary["x"] = ary2[1];
	    ary["y"] = "";
	# Image alignment
	} else if (ary[a] ~ /^(top|middle|bottom|text-top|text-bottom|baseline|sub|super)$/) {
	    css = css "vertical-align:" ary[a] ";"; 
	} else if (ary[a] ~ /^(left|right|center|none)$/) {
	    css = css "float:" ary[a] ";"; 
	} else if (ary[a] ~ /^(alt=)/) {
	    ary["attr"] = ary["attr"] " alt='" substr(ary[a], 1 +4) "'";
	} else if (ary[a] ~ /^(link=)/) {
	    ary["link"] = substr(ary[a], 1 + 5);
	} else if (ary[a] ~ /^(page=)/) {
	    ; # not supported
	} else {
	    title = ary[a];
	}
    }
    if (ary["frame"] ~  /^(thumb|frameless)$/ && ! ary["x"])
	ary["y"] = ary["x"] = 80;
#	    if (! ary["x"]) ary["x"] = 80;
#	    if (! ary["y"]) ary["y"] = 80;

    if (css) ary["attr"] = ary["attr"] " style='" css "'";

    # TODO: handle by wiki?
    if (ary["link"] == "0" && ary["link"] = img_key(location))
	ary["link"] = OPT[ary["link"] "_URL"] "/" location;

    if (ary["frame"] ~ /^(thumb|frame)$/) {
	html_tag("div", "class='frame' style='display:table-cell'");
	printf "%s", img("File:", location, title, ary);
	html_tag("br");
	printf "%s", title;
	html_close("div");
    } else {
	printf "%s", img("File:", location, title, ary);
    }
}
function text2html(str,  ary, left, e) {
    # Creole Nowiki (Preformatted) Inline 
    if (left = index(str, "{{{")) {
	if (e = rindex(substr(str, left), "}}}")) {
	    text2html(substr(str, 1, left - 1));
	    html_tag("tt");
	    printf "%s", raw2html(substr(str, left +3, e-3-1), 1);
	    html_close("tt");
	    text2html(substr(str, left + 3 + e - 1));
	    return;
	}
    }
    
    # MediaWiki <nowiki> tag, 
    if (match(str, /<(code|pre|nowiki)[^>]*>/, ary)) {
	left = substr(str, 1, RSTART - 1);
	str = substr(str, RSTART + RLENGTH);
	text2html(left);
	if (match(str, "</" ary[1] "[^>]*>")) {
	    left = substr(str, 1, RSTART -1);
	    str = substr(str, RSTART + RLENGTH);
	    html_tag(ary[1] == "nowiki" ? "tt" : ary[1], "", raw2html(left,1));
	    text2html(str);
	} #else # FIXME: !
#	    html_tag("tt", "", raw2html(str));
	return 
    }


    # Creole Nowiki Escape Character
    if ((left = index(str, "~")) \
	 && substr(str, left) !~ /^~($|[[:space:]])/ \
	 && substr(str, 1, left -1) !~ /(https?|ftp|gopher|mailto|news):\/\/[^[:space:]]*$/  \
	 ) {
	if (left > 1) text2html(substr(str, 1, left -1));
	if (length(str) > left) printf "%s", raw2html(substr(str, left +1 ,1));
	if (length(str) >= left +2) text2html(substr(str, left +2));
	return;
    }

    # check <ref>..</ref>
    left = "";
    while (match(str, /<ref[^>]*>/)) {
	left = left substr(str, 1, RSTART -1);
	str = substr(str, RSTART + RLENGTH);
	if (match(str, /<\/ref[[:space:]]*>/)) {
	    e = ary_u_add(REF, substr(str, 1, RSTART -1));
	    left = left \
		sprintf("<sup>[<a href='#_ref_%d' name='ref_%d' class='ref'>%d</a>]</sup>" \
		, e, e, e);
	    str = substr(str, RSTART + RLENGTH);
	}
    }
    str = left str;

    # Creole images
    while (match(str, /{{([^\|}]+)(\|(.*))?}}/,ary)) {
	str = substr(str, 1, RSTART -1) \
	    img("", ary[1], (ary[3] ? ary[3] : ary[1])) \
	    substr(str, RSTART + RLENGTH);
    }

    # MediaWiki images (no external)
    while (match(str, /\[\[(image|file):([^\]\|]+)(\|([^\]]*))?\]\]/, ary)) {
	left = substr(str, 1, RSTART -1);
	str = substr(str, RSTART + RLENGTH);
	text2html(left);
	mw_img(ary[2], ary[3]);
	text2html(str);
	return;
    }
 
    # checking links (1. MediaWiki, 2. & 3. Creole & MediaWiki)
    while ((e = match(str,/(^|[^\[])\[((https?|ftp|gopher|mailto|news):\/\/[^[:space:]\]]+)([[:space:]]*([^\]]+))?(\])/, ary)) \
	  || match(str,/()\[\[(()[^\]\|]+)(\|([^\]]+))?\]\]/, ary) \
	  || match(str,/(^|[^'">:])((https?|ftp|gopher|mailto|news):\/\/[^[:space:]\]]+)/, ary) \
	   ) {
	# (pre) (url) (proto) (caption with space) (caption without space) ]
	#  [http://...
	# (epmty) 
	#  [[...]]
	# (pre)
	#  "http://..
	left = substr(str,1, RSTART -1 + length(ary[1]));
	if (e && !ary[5])  {
	    left = left a_href(ary[2], "[" (e = ary_index(ELINKS, ary[2])) "]");
	    if (ELINKS[0] < e) ELINKS[0] = e;
	} else {
	    # MediaWiki external Images
	    if (OPT["EXTERNAL_IMG"] && !e && !ary[5] && ary[2] ~ /\.(gif|png|jpe?g)/) {
		left = left img("", ary[2], ary[2]);
	    } else {
		left = left a_href(ary[2], (ary[5]) ? ary[5] : ary[2]);
	    }
	}
	str = left substr(str, RSTART + RLENGTH);
    }

 if (0) { # auto paragraph ??
#    if (! trim(str)) return;

    e = TAG[0];
    while (e > 0 \
	&& TAG[e] !~ /^(p|pre|table)$/ \
	&& TAG[e] !~ REGEX_HTML["LIST"] \
	) e --;
#   printf "[CHECK P:%s]",e; 
    if (! e) html_tag("p");
 }
    # FIXME: quick & dirty
    if ((left = is_word(str)) && left = have_doc(left)) {
	printf "%s", a_href(left, str);
    } else {
        printf "%s", formating(raw2html(str));
    }
}
function trim(str,f , a, b) {
    gsub(/^[[:space:]]+/, "", str);
    gsub(/[[:space:]]+$/, "", str);
a = RSTART;
b = RLENGTH;
    # f=2 unique (header) name
    # f=3 internal link name
    if (f >= 4)
	while (match(str, / +([0-9A-Za-z])/))
	    str = substr(str, 1, RSTART -1) \
	   	 toupper(substr(str, RSTART + RLENGTH -1, 1)) \
	   	 substr(str, RSTART + RLENGTH);
	    
RSTART = a;
RLENGTH = b;
    if (f >= 3)  
	gsub(/[^a-zA-Z0-9_-]+/, "_", str);
    else if (f >= 2) {
	gsub(/[^a-zA-Z0-9_]+/, "_", str);
	# id=
	if (str !~ /^[a-zA-Z]/) str = "X" str;
    } else if (f)
	gsub(/[[:space:]_]+/, "_", str);

    if (f) gsub(/(^_+|_+$)/, "", str);
    return (f >= 3) ? substr(str, 1, OPT["MAX_INTERNALLINK_LENGTH"]): str;
}
function unique_name(str,  i,add) {
    str = trim(str, 2);
    add = "";
    while (1) {
	i = HTML_ID[0];
	while (i > 0 && HTML_ID[i] != str add) i --;
	if (!i) return (HTML_ID[++HTML_ID[0]] = str add);
	add += 1;
    }
}

// {
    RAW = RAW $0 "\n";
    if (CGI["debug"]) printf "<!-- %s:%d\n%s\n-->", FILENAME, FNR, $0;
    if (CGI["mode"] == "source") {
	if (TAG[0] == 0 || TAG[TAG[0]] != "pre") 
	    html_tag("pre"); #, "class='CSS Text'");
	print raw2html($0, 1);
	next;
    }
}
function list_wiki2html(lists, attr, i,last_level,skip_levels) {

    if (attr) attr = " " attr;
    last_level = 0;
    skip_levels = 0; 

    for (i = 1; i <= TAG[0]; i ++)
	if (TAG[i] ~ REGEX_HTML["LIST"])  {
	    last_level ++;
	    if (skip_levels == last_level -1 \
		&& last_level <= length(lists)  \
		&& TAG[i] == CHAR2LIST[substr(lists, last_level,1)] \
		) skip_levels ++;
	}

    html_debug(sprintf("list levels %d of %d start %d" \
	, length(lists), last_level, skip_levels));

    for (i = skip_levels +1; i<= last_level; i++) {
	html_debug("close parent list");
	# close nested list item
	if (TAG[0] > 0 && TAG[TAG[0]] ~ REGEX_HTML["ITEM"]) html_close();
	html_close(); # close list
    }
   
    if (skip_levels < last_level) {
	# close parent list item
        if (TAG[0] > 0 && TAG[TAG[0]] ~ REGEX_HTML["ITEM"]) {
	    html_debug("close parent list item");
	    html_close();
	}
    }
    
    # open child list
    for (i = 1 + skip_levels; i <= length(lists); i++) {
	if (i - skip_levels > 1) {
	    html_debug("item for child list");
	    html_tag((TAG[TAG[0]] == "dl") ? "dd" : "li", attr); # nested list
	}
	if (TAG[TAG[0]] == "dt") {
	    html_close();
	    html_tag("dd", attr);
	}
	html_debug(sprintf("new list in level %d", i));
	html_tag(CHAR2LIST[substr(lists, i, 1)], attr);
    }
    # open current list item
    html_tag(CHAR2ITEM[substr(lists, length(lists),1)], attr);
}
### parsing ###
# Creole table
match($0, /^\|/,ary) && (! TABLE || $0 ~ /[^\|]\|$/) {
    str = substr($0, RSTART + RLENGTH);
    if (str !~ /[[:space:]]*\|$/) str = str "|";
    if (! CREOLE_TABLE) {
	CREOLE_TABLE ++;
	html_tag("table");
    }
    html_tag("tr");
    while ((i = index(str, "|")) > 0) {
	text = substr(str, 1, i -1);
	str = substr(str, i +1);
	if (substr(text, 1, 1) == "=") {
	    tag = "th";
	    text = substr(text, 2);
	} else {
	    tag = "td";
	}
	if (attr = detect_align(text)) attr = "align='" attr "'";

	html_tag(tag, attr);
	text2html(text);
	html_close(tag);
    }
    
    html_close("tr");
    next;
}
CREOLE_TABLE {
    html_close("table");
    CREOLE_TABLE --;
}
# Headings
match($0, /^(=+)([^=]+)(=+)/, ary) {
    HEADING_LEVEL = length(ary[length(ary[1]) >= length(ary[3]) ? 1 : 3]);
    html_head(HEADING_LEVEL, ary[2]);
    next;
}
# MediaWiki table
match($0,/^[[:space:]]*\{\|/) {
    attr = substr($0, RSTART + RLENGTH);
    text2html(substr($0,1, RSTART-1));
    html_tag("table", attr);
    TABLE ++;
    next;
}
# .. row
TABLE && match($0, /^[[:space:]]*\|-/) {
    attr = substr($0, RSTART + RLENGTH);
    html_tag("tr", attr);
    next;
}
# .. end
TABLE && match($0, /^[[:space:]]*\|\}/) {
    html_tag("-");
    if (TAG[0] > 0 && TAG[TAG[0]] ~ /^(td|th)$/) html_close();
    if (TAG[0] > 0 && TAG[TAG[0]] ~ /^(tr)$/) html_close();
#printf "<!-- closing table -->";
    html_close("table");
    TABLE --;
    next;
}
# .. cell
TABLE && match($0,/^[[:space:]]*([\|!])/,ary) {
    tag = (ary[1] == "!") ? "th" : "td";
    str = substr($0, RSTART + RLENGTH);
    str = str ary[1] ary[1];
    while ((i = index(str, ary[1] ary[1])) > 0) {
	text = substr(str, 1, i -1);
	str = substr(str, i +2);
	attr = "";
	if ((i = index(text, "|")) && substr(text, 1, i-1) !~ /[\[<{]/) {
	    attr = substr(text, 1, i -1);
	    text = substr(text, i +1);
	}

	if (! attr && \
	    substr(str, 1, length(str) -2 ) ~ /([ \|!])$/ && \
	    (attr = detect_align(text))) attr = "align='" attr "'";
	
	html_tag(tag, attr);
	text2html(text);
    }
    next;
}

# unordered-, ordered- and definition list
(/^([#;:\*]+)/ && match(formating($0), /^([#;:\*]+)/)) {
    lists = substr($0, 1 ,RLENGTH);
    $0 = substr($0, RSTART + RLENGTH);
    list_wiki2html(lists);
    if (lists ~ /;/ && 1) { # FIXME: meta vs. link 
	if (match($0, /: +[^ ]/)) {
	    i = RSTART;
	    rest = substr($0, i);
	    $0 = substr($0, 1, i -1);
	} else {
	    rest = "";
	}
	if (DT_WORD = is_word($0)) {
	    ary_u_add(KEYWORDS, DT_WORD);
	    if (d = have_doc(DT_WORD)) {
		printf "<a name='%s' id='%s' href='%s' class='intern'>%s</a>" \
		    , u = add_toc(HEADING_LEVEL +1, d) \
		    , u, DT_WORD, $0
		    ;
		$0 = "";
	    }
	} 
	if ($0) {
	    html_tag("a" \
		, sprintf("name='%s' id='%s' href='#%s' class='head'" \
		         , u = add_toc(HEADING_LEVEL +1, $0), u, u \
			 ) \
		);
	    text2html($0);
	    html_close("a");
        }

	if (rest) {
	    list_wiki2html(substr(lists, 1, length(lists) -1) substr(rest, 1, 1));
	    $0 = substr(rest, 2);
	    if (FILE2TYPE[FILENAME] == "DOC" && DT_WORD && val = is_word($0)) 
		KEYVALUE[DT_WORD] = val;
	} else {
	    next;
	}
    } else if (lists ~ /:/) {
	if (FILE2TYPE[FILENAME] == "DOC" && DT_WORD && val = is_word($0)) 
	    KEYVALUE[DT_WORD] = val;
    } else {
	DT_WORD = "";
    }
    text2html($0);
    next;
}
DT_WORD = "";
# MediaWiki preformated line (but wiki interpreted)
/^ / {
#       printf "<!-- last TAG(%d)='%s'-->", TAG[0],TAG[TAG[0]];
   if (TAG[0] == 0 || TAG[TAG[0]] != "pre") html_tag("pre");
   text2html(substr($0, 2));
   printf "\n";
   next;
}
# Creole nowiki preformatted 
/^{{{/ {
    if (! rindex($0, "}}}")) {
	html_tag("pre");
	while (getline) {
	    RAW = RAW $0 "\n";
	    if ($0 ~ /^}}}/) break;
	    print raw2html($0,1);
	}
	html_close("pre");
	next;
    }
}
/^----/ {
    html_tag("hr");
    $0 = substr($0, 5);
}
/[^[:space:]]/ {
    if (match($0, /<(code|nowiki|pre)([^>]*)>/,ary)) {
	tag = tolower(ary[1]);
	tag_attr = ary[2];
	# text before tag
	text = substr($0, 1, RSTART  -1);
	$0 = substr($0, RSTART + RLENGTH);

	if (trim(text)) {
            html_tag("p");
	    text2html(text);
	    html_debug("text before html");
	} else if (tag != "pre") 
	    html_tag("p");
	
	if (tag == "nowiki") 
	    html_tag("tt");
	else
	    html_tag(tag, tag_attr);

	while(! match(tolower($0), "</" tag "[[:space:]]*>")) {
	    html_debug("html line");
	    printf "%s\n", raw2html($0, 1);
	    if (getline <= 0) {
		html_warn("missing closing tag " tag);
		break;
	    }
	    RAW = RAW $0 "\n";
	}

	if (RSTART) {
	    text = substr($0, RSTART + RLENGTH);
	    $0 = substr($0, 1, RSTART -1);
	    printf "%s", raw2html($0, 1);
	    html_debug("last html line");
	    html_close((tag == "nowiki") ? "tt" : tag);
	    if (trim(text)) {
		html_tag("p");
		text2html(text);
	    }
	}
    } else {
        html_tag("p");
	text2html($0);
	html_debug("text end");
    }
    next;
}
// {
    html_tag("-"); # close the last tag
}
