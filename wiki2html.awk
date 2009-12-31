#! /usr/bin/gawk -f
#
# Copyright (c) 2009 Christian W. Moenneckes
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
    OPT["CSS_SCREEN"]  = "../wiki.css";
    OPT["DOC_DIR"]     = "wikidocs";
    OPT["DRAFT_VIEW"]  = 1;
   
    OPT["INDENT"] = 4;

    # 1: for edit 
    # 2: for edit & view source
    # 3: for edit & view source & view draft 
    OPT["LOGIN"] = 0;

    UPTIME = uptime();
    
    TABLE = 0;
    CREOLE_TABLE = 0;
    
    TAG[0] = 0;      # HTML tag stack
    IN_TAG[0] = 0;   # HTML tag counter
    HTML_ID[0] = 0;
    
    RAW = "";
    SELF = "";
    RW = 0;

    L_COUNT = 0;
    
    REF[0] = 0;
    ELINKS[0] = 0;
    
    DOC = "";
    
    DST_FILE = "";
    SRC_FILE = "";

    CGI[0] = 0;

    EXIT = 0;
    CGI["debug"] = 0;

    if (ENVIRON["SERVER_PROTOCOL"] ~ /^HTTP/) {
	
	if (OPT["DOC_DIR"] !~ /^\// \
	    && match(ENVIRON["SCRIPT_FILENAME"], /^(.*\/)([^\/]+)$/, ary))
	    OPT["DOC_DIR"] = ary[1] OPT["DOC_DIR"];
	
	if (OPT["IMG_DIR"] !~ /^\// \
	    && match(ENVIRON["SCRIPT_FILENAME"], /^(.*\/)([^\/]+)$/, ary))
	    OPT["IMG_DIR"] = ary[1] OPT["IMG_DIR"];
	
	SELF = "http://" ENVIRON["SERVER_NAME"] ENVIRON["SCRIPT_NAME"];
	if (ENVIRON["REQUEST_METHOD"] == "POST") {
	    getline query < ("/dev/stdin");
	    close("/dev/stdin");
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
	} else if (match(ENVIRON["PATH_INFO"], /^\/([a-zA-Z0-9_-]+)$/, ary) \
		&& 3 <= RLENGTH -1 && RLENGTH <= 32 \
		) {
	    ARGC =1;
	    DOC = gensub(/_/, " ", "g", docfile = ary[1]);

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

	    SRC_FILE = OPT["DOC_DIR"] "/" docfile;

	    if (OPT["DRAFT_VIEW"]) {
		draftfile = SRC_FILE ".draft";
	    } else {
		if (CGI["mode"] ~ /^(draft|edit-draft|diff-draft)$/)
		    CGI["mode"] = "";

		draftfile = OPT["TMP_PREFIX"] docfile;
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
		    printf "Location: %s/%s\n\n", SELF, docfile;
		    exit(EXIT = 3);
		}
		savefile = OPT["DOC_DIR"] "/"  docfile;
		if (OPT["USE_SYMLINK"])
		    if(system(sprintf("ln -sfn %s%s %s" \
		       , savefile, strftime("-%Y%m%d-%H%M%S"), savefile)))
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
		}
		ARGV[ARGC++] = viewfile;
	    }
	    
	    if (savefile) {
#		printf "writing %s\n", savefile >> "/dev/stderr";
		printf "%s", CGI["txt"] > savefile;
		close(savefile);
		if (CGI["mode"] == "save") {
		    printf "Location: %s/%s\n\n", SELF, docfile;
		    exit(EXIT = 4);
		}
		ARGV[ARGC++] = savefile;
	    } 
	} else
	    errstr = sprintf("Invalid document: %s\n",ENVIRON["PATH_INFO"]);
	
	printf "Content-Type: text/html\n\n";
    }
#    print "<!DOCTYPE html PUBLIC '-//W3C//DTD HTML 4.01 Transitional//EN' 'http://www.w3.org/TR/html4/loose.dtd'>";
    print "<!DOCTYPE html PUBLIC '-//W3C//DTD HTML 4.01//EN' 'http://www.w3.org/TR/html4/strict.dtd'>";
    html_tag("html");
    html_tag("head");
    html_tag("title", "", raw2html(((CGI["mode"]) ? "" CGI["mode"] ":" : "") DOC,1));

    html_tag("meta", "http-equiv='Content-type' content='text/html;charset=UTF-8'");

    if (CGI["refresh"] && ! CGI["mode"])
	html_tag("meta", "http-equiv='refresh' content='7'");

    if (OPT["CSS_SCREEN"])
	html_tag("link", sprintf("rel='stylesheet' media='screen' type='text/css' href='%s'", OPT["CSS_SCREEN"]));

#    html_close("head");
    html_tag("body");
    if (errstr) {
	printf "<p class='error'>%s</p>\n", errstr;
	exit(EXIT = 0);
    }
    if (CGI["debug"] >= 2) {
	html_tag("pre");
        printf "ARGC=%s\nARGIND=%s\n<hr>",ARGC,ARGIND;
	
	printf "PROCINFO\n"
	for (v in PROCINFO) printf " %s=%s\n", v, PROCINFO[v];

	printf "ENVIRON\n"
	for (v in ENVIRON) printf " %s=%s\n", v, ENVIRON[v];
	
	printf "CGI\n"
	for (v in CGI) printf " %s=%s\n", v, CGI[v];

	printf "OPT\n"
	for (v in OPT) printf " %s=%s\n", v, OPT[v];

#	system("env");
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
}
END {
    if (EXIT) exit(EXIT);

    if (REF[0] && TAG[0]) {
	html_tag("h2", "", "References");
	html_tag("ol"); # ul
	for (i = 1; i <= REF[0]; i ++) {
	    html_tag("li");
	    printf "<a href='#ref_%d' name='_ref_%d' class='ref'>&uarr;</a> " \
		, i, i;
	    text2html(REF[i]);
	    html_close("li");
	}
	html_close("ol");
    } else {
	html_tag("-"); # close the last tag
    }

    if (ENVIRON["SERVER_PROTOCOL"] ~ /^HTTP/ && TAG[0]) {
	html_tag("hr");

	if (RW && (CGI["mode"] == "edit" \
		|| CGI["mode"] == "preview" \
		|| CGI["mode"] == "diff-edit" \
		)) {
	    if (CGI["mode"] == "edit") CGI["txt"] = RAW;
	    printf "<a name='edit'></a>";
	    printf "\n<form method='POST' action='%s%s'>" \
		    , ENVIRON["SCRIPT_NAME"] \
		    , ENVIRON["PATH_INFO"] \
		    ;
	    txt = CGI["txt"];
	    gsub(/\&/, "\\&amp;",txt);
	    printf "\n<textarea style='width:100%' rows='25' name='txt'>%s</textarea>",txt;
	    printf ("<div style='width:100%;' class='tool'>");
	    ary[0] = split("preview save cancel",ary);
	    if (OPT["DRAFT_VIEW"]) ary[++ary[0]] = "discard";
	    if (SRC_FILE) ary[++ary[0]] = "diff-edit";
	    for (i = 1; i <= ary[0]; i ++)
		printf "<input type='submit' name='mode' value='%s' class='tool'>", ary[i];
	    if (OPT["LOGIN"])
		printf "User: %s\n", ENVIRON["REMOTE_USER"];

	    printf "</div>\n";
	    printf "</form>";
	} else {
	    printf ("<div style='width:100%;' class='tool'>");
	    printf "<a href='%s?mode=' class='tool'>toc</a>\n", SELF;

	    printf "<a href='?mode=' class='tool'>reload</a>\n";
	    
	    if (SRC_FILE && (OPT["LOGIN"] <= 2 || ENVIRON["REMOTE_USER"]))
	        printf "<a href='?mode=source' class='tool'>source</a>\n";
	    
	    if (DST_FILE && OPT["DRAFT_VIEW"]) {
	        printf "<a href='?mode=draft' class='tool'>draft</a>\n";
		if (SRC_FILE) 
		    printf "<a href='?mode=diff-draft' class='tool'>diff-draft</a>\n";
		if (RW) 
		    printf "<a href='?mode=edit-draft' class='tool'>edit-draft</a>\n";
	    } else if (RW)
		printf "<a href='?mode=edit#edit' class='tool'>edit</a>\n";

	    if (OPT["LOGIN"]) {
		if (ENVIRON["REMOTE_USER"])
		    printf "User: %s\n", ENVIRON["REMOTE_USER"];
		else
		    printf "<a href='?mode=login' class='tool'>login</a>\n";
	    }
	    
	    print "<a href='http://validator.w3.org/check?uri=referer' class='etool'>validate HTML</a>";
	    print "<a href='http://jigsaw.w3.org/css-validator/check/referer' class='etool'>validate CSS</a>";
	    printf "</div>\n";
	}
	if (UPTIME) {
	    printf("<hr><div><i>%s (-%.2fs)</i></div>" \
	       , strftime("%A %F %T %Z")\
	       , uptime() - UPTIME \
	       );
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
function f_readable (file, c) {
    if (file ~ /^\/dev\/std(out|err)/) return 0;
#    if (file ~ /[\/\?\*]/) exit; # FIXME ?
    c = getline < (file);
    close(file);
    return c;
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
function html_close(tag, i, t) {
    if (TAG[0] <= 0) {
	printf "<span class='error'>no more html tags to close</span><br>"; 
	return;
    }

    t = TAG[0];
    if (tag) 
	while (t > 0 && TAG[t] != tag) {
	    if (t != TAG[0]) 
		printf "<span class='error'>&lt;%s&gt; not open</span><br>", TAG[t];
	    t --;
	}

    # close after newline ?
    if (TAG[TAG[0]] !~ /^(a|dd|dt|h[1-9]|li|p|pre|title)$/) {
	printf "%s", html_debug("closing tag");
	#if (TAG[TAG[0]] != "p") 
	printf "\n";
        i = (TAG[0]-1) * OPT["INDENT"];
        while (i -- > 0) printf " ";
    }
   
    while (TAG[0] >= t) {
	if (TAG[0] > t)
	    printf "<span class='error'>closing tag %s to close %s</span><br>" \
		, TAG[TAG[0]], tag;
	printf "</%s>", TAG[TAG[0]--];
    }
}
function html_tag(tag,attr,html,  i) {
    if (TAG[0] > 0) {
#    printf "\n<!-- new tag %s statck: ", tag;
 #   for (i = 1; i <= TAG[0]; i ++)
#	printf " %s", TAG[i];
 #   printf "-->";
	# .. keep <pre> & <table> in lists
#	if (tag !~ /^(dl|dt|dd|ol|ul|li)$/) 
	if (tag !~ /^(dl|dt|dd|ol|ul|li|pre|table|tt|)$/) {
	    if (TAG[TAG[0]] ~ /^(li|dt|dd)$/) 
		html_close();
	    while (TAG[0] > 0 && TAG[TAG[0]] ~ /^(dl|ol|ul)$/) {
		html_close(); # close list
		L_COUNT --;
		if (L_COUNT) html_close(); # close item in nested list
	    }
	}
 
	if (tag == "body") {
	    if (TAG[TAG[0]] == "head")  html_close();
	} else if (tag == "tr") {
	    if (TAG[TAG[0]] == tag)
		return 0;
#	    else if (TAG[TAG[0]] ~ /^(pre)$/) 
#		html_close();
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
	} else if (tag ~ /^(|-|h[1-6]|hr|p)$/) {
	    if (TAG[TAG[0]] == tag) {
		printf "%s\n", html_debug("next line from same tag"); 
		return 0;
	    } else if (TAG[TAG[0]] ~ /^(hr|h[1-6]|p|pre|table|li|dt|dd)$/) 
		html_close();
	# no recursive tags
	#} else if (tag ~ /^(|-|h[1-6]|hr|p|pre|table)$/) {
	} else if (tag ~ /^(pre|table)$/) {
	    if (TAG[TAG[0]] == tag) {
		printf "%s\n", html_debug("next line from same tag"); 
		return 0;
	    # tags welche sich gegenseitig ausschliessen
	    } else if (TAG[TAG[0]] ~ /^(hr|h[1-6]|p|pre|table)$/) 
		html_close();
	# lists
	} else if (tag ~ /^(dl|ol|ul)$/) {
	    if (TAG[TAG[0]] ~ /^(p|pre|table|tr)$/) 
		html_close();
	# list items
	} else if (tag ~ /^(dd|dt|li)$/) {
	    if (TAG[TAG[0]] ~ /^(p|pre|table|tr|dd|dt|li)$/) 
		html_close();
#	    if (TAG[0] <= 0 || TAG[TAG[0]] !~ /!/)
        }
	
    }
    if (tag == "" || tag == "-") return 0;

  #  printf "\n<!-- + tag stack:";
 #   for (i = 1; i <= TAG[0]; i ++)
#	printf " %s", TAG[i];
 #   printf "-->";
   
    printf "%s\n", html_debug("new tag");
    i = TAG[0] * OPT["INDENT"];
    while (i -- > 0) printf " ";

    IN_TAG[tag] ++;
    if (attr = trim(attr)) 
	attr = " " attr;
    else if (tag == "tr")
	attr = " class='" ((IN_TAG[tag] % 2) ? "even" : "odd") "'";

    if (tag !~ /^(br|hr|link|meta)$/) TAG[++TAG[0]] = tag;
    printf "<%s%s>%s", tag, attr, html;
    if (html && TAG[TAG[0]] == tag) {
	printf "</%s>\n", TAG[TAG[0]--];
    }
#    printf "<!-- tag %s open-->", tag;
    return 1;
}

function ary_index(ary, element, i) {
    i = 1;
    while (i <= ary[0] && ary[i] != element) i++;
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
    else if (text ~ /^[[:space:]]*[0-9]+[0-9,']*(\.[0-9]+)?([[:space:]]+.*|)$/)
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
function a_href(link, html, class) {
    if (link ~ /^#/) {
	if (! html) html = substr(link, 2);
        link = "#" gensub(/ /, "_", "g", substr(link, 2));
        class = "local";
    } else if (link ~ /^[^\/]+$/) { # internal
        if (! html) html = link;
        gsub(/ /, "_", link);
	if (f_readable(OPT["DOC_DIR"] "/" link) > 0)
	    class = "intern";
	else 
	    class = "intern_missing";
    } else {
        if (! html) html = link;
        class = "extern";
    }
    return sprintf("<a href='%s' class='%s'>%s</a>", link, class, html);
}
function img(prefix, location, title, attr, link) {
    if (attr ~ /^[^[[:space:]]/) attr = " " attr;
    if (attr !~ /alt=/) attr = attr " alt='" title "'";
    if (title) title = " title='" title "'";
    if (location ~ /^(.+:\/\/) && ! prefix/) { # FIXME: Creole external image ?
	return sprintf("<a href='%s' class='extern'%s>%s</a>" \
		    , (link) ? link : location, title, location);
    } else if (index("/" location "/", "/../") \
	    || f_readable(OPT["IMG_DIR"] "/" location) <0) {
	return sprintf("<a href='%s' class='intern_missing'%s>%s%s</a>" \
		    , ((link) ? link : OPT["IMG_URL"] "/" location) \
		    , title, prefix, location);
    } else if (link) {
	return a_href(link, sprintf( "<img src='%s/%s'%s>" \
			         , OPT["IMG_URL"], location,  attr title));
    } else {
        return sprintf("<img src='%s/%s'%s>" \
		, OPT["IMG_URL"], location,  attr title);
    }
}
# MediaWiki image attributes
function mw_img(location, opts,  ary, a, title, attr, link, ary2) {
    ary[0] = split(opts, ary, /\|/);
    title = attr = link = "";
    for (a = 1; a <= ary[0]; a ++) {
	# Image format
	if (ary[a] == "border") {
	    attr = attr " class='bordered'";
	} else if (ary[a] == "frame") {
	    ; # not supported
	} else if (ary[a] ~ /^(thumb|frameless)$/) {
	    attr = attr " width='80' height='80'"; # not really supported
	# 
	} else if (match(ary[a], /^([0-9]+)x([0-9]+)px$/, ary2)) {
	    attr = attr " width='" ary2[1] "' height='" ary2[2] "'";
	} else if (match(ary[a], /^([0-9]+)px$/, ary2)) {
	    attr = attr " width='" ary2[1] "'";
	# Image alignment
	} else if (ary[a] ~ /^(top|middle|bottom)$/) {
	    attr = attr " align='" ary[a] "'"; 
	} else if (ary[a] ~ /^(left|right|center|none)$/) {
	    ; # not supported
	} else if (ary[a] ~ /^(baseline|sub|super||text-top|text-bottom)$/) {
	    ; # not supported
	} else if (ary[a] ~ /^(alt=)/) {
	    attr = attr " alt='" substr(ary[a], 1 +4) "'";
	} else if (ary[a] ~ /^(link=)/) {
	    link = substr(ary[a], 1 + 5);
	} else if (ary[a] ~ /^(page=)/) {
	    ; # not supported
	} else {
	    title = ary[a];
	}
    }
    return img("File:", location, title, attr, link);
}
function text2html(str,  ary, left, start, e) {

#    gsub(/\r/, "", str); FIXME: needed?

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
    
    # MediaWiki <nowiki> tag
    if (match(str, /<nowiki[^>]*>/, ary)) {
	left = substr(str, 1, RSTART - 1);
	str = substr(str, RSTART + RLENGTH);
	text2html(left);
	if (match(str, /<\/nowiki[^>]*>/)) {
	    left = substr(str, 1, RSTART + RLENGTH - 1);
	    str = substr(str, RSTART + RLENGTH);
	    html_tag("tt", "", raw2html(left));
	    text2html(str);
	} else # FIXME: !
	    html_tag("tt", "", raw2html(str));
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
    left = 0;
    while (match(substr(str, left +1), /<ref[^>]*>/)) {
	start = left + RSTART + RLENGTH;
	left += RSTART -1;
	if (match(substr(str, left), /<\/ref[[:space:]]*\>/)) {
	    e = ary_index(REF, start = substr(str, start, left + RSTART -1 - start));
	    if (REF[0] < e) REF[0] = e;
	    REF[REF[0]] = start;
	    str = substr(str, 1, left) \
		sprintf("<sup>[<a href='#_ref_%d' name='ref_%d' class='ref'>%d</a>]</sup>" \
		, REF[0], REF[0], REF[0]) \
		substr(str, left + RSTART + RLENGTH);
	}
    }

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
	str = left mw_img(ary[2], ary[3]) str;
    }
 
    # checking links (1. MediaWiki, 2. & 3. Creole & MediaWiki)
    while ((e = match(str,/(^|[^\[])\[((https?|ftp|gopher|mailto|news):\/\/[^[:space:]\]]+)([[:space:]]*([^\]]+))?(\])/, ary)) \
	  || match(str,/()\[\[(()[^\]\|]+)(\|([^\]]+))?\]\]/, ary) \
	  || match(str,/(^|[^'">])((https?|ftp|gopher|mailto|news):\/\/[^[:space:]\]]+)/, ary) \
	   ) {
	# (pre) (url) (proto) (caption with space) (caption without space) ]
	# (epmty) 
	# (pre)
	left = substr(str,1, RSTART -1 + length(ary[1]));
	if (e && !ary[5])  {
	    left = left a_href(ary[2], "[" (e = ary_index(ELINKS, ary[2])) "]");
	    if (ELINKS[0] < e) ELINKS[0] = e;
	} else {
	    left = left a_href(ary[2], (ary[5]) ? ary[5] : ary[2]);
	}
	str = left substr(str, RSTART + RLENGTH);
    }
    
    printf "%s", formating(raw2html(str));
}
function trim(str,f) {
    gsub(/^[[:space:]]+/, "", str);
    gsub(/[[:space:]]+$/, "", str);

    if (f >= 2) 
	gsub(/[^a-zA-Z0-9_]+/, "_", str);
    else if (f)
	gsub(/[[:space:]_]+/, "_", str);

    if (f) gsub(/(^_+|_+$)/, "", str);
    return str;
}
function html_attr_id(str,  i,add) {
    str = trim(str,2);
    add = "";
    while (1) {
	i = HTML_ID[0];
	while (i > 0 && HTML_ID[i] != str add) i --;
	if (!i) return "id='" (HTML_ID[++HTML_ID[0]] = str add) "'";
	add += 1;
    }
}

// {
    RAW = RAW $0 "\n";
    if (CGI["debug"]) printf "\n<!-- %s -->", $0;
    if (CGI["mode"] == "source") {
	if (TAG[0] == 0 || TAG[TAG[0]] != "pre") 
	    html_tag("pre"); #, "class='CSS Text'");
	print raw2html($0, 1);
	next;
    }
}
### parsing ###
# Creole table
! TABLE && match($0, /^\|/,ary) {
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
    h = length(ary[length(ary[1]) >= length(ary[3]) ? 1 : 3]);
    text = substr(ary[1], h +1) ary[2] substr(ary[3], h +1);
    html_tag("h" h, html_attr_id(text), raw2html(text,1));
#    text2html(text);
#    html_close("h" h);
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
	attr = (i = index(text, "|")) ? substr(text, 1, i -1) : "";
	text = substr(text, i +1);

	if (! attr && (attr = detect_align(text))) attr = "align='" attr "'";
	
	html_tag(tag, attr);
	text2html(text);
    }
    next;
}
# unordered-, ordered- and definition list
(/^([#;:\*]+)/ && match(formating($0), /^([#;:\*]+)/)) {

#    if (i = 1; i <= RLENGTH; i ++)
#	if (substr($0, i, 1) == "*")
#	    dst_lists[i] = "ul";
#	else if (substr($0, i, 1) == "#")
#	    dst_lists[i] = "ol";
#	else
#	    dst_lists[i] = "dl";

    list = substr($0,RSTART + RLENGTH-1,1);
   
    if (list == "*") {
	list = "ul"; # falls verschachtelt dann in <li></li>
	item = "li";
    } else if (list == "#")  {
	list = "ol"; # falls verschachtelt dann in <li></li>
	item = "li";
    } else if (list == ";") {
	list = "dl"; # falls verschachtelt dann in <dd></dd>
	item = "dt";
    } else if (list == ":") {
	list = "dl"; # falls verschachtelt dann in <dd></dd>
	item = "dd";
    }
    $0 = substr($0, RSTART + RLENGTH);
    c = RLENGTH;

    # close the last list item
    if (TAG[0] > 0 && TAG[TAG[0]] ~ /^(li|dd|dt)$/) html_close();

  if (1) {
    while (L_COUNT > c) {
	L_COUNT --;
	html_close(); # close list
	if (L_COUNT) html_close(); # close item
    }
    for (i = 1 + L_COUNT; i <= c; i++) {
	if (L_COUNT) 
	    html_tag((TAG[TAG[0]] == "dl") ? "dd" : "li"); # nested list
	html_tag(list);
	L_COUNT ++;
    }
  } else {
    
#    printf "<!-- open do list prepare -->";
    for (i = 1 + L_COUNT; i <= c; i++) {
	if (L_COUNT) html_tag((item == "li") ? "li" : "dd"); # nested list
	html_tag(list);
	L_COUNT ++;
    }
#   printf "<!-- closing -->";
    while (L_COUNT > c) {
	L_COUNT --;
	html_close(); # close list
	if (L_COUNT) html_close(); # close item
    }
  }
#    printf "<!-- open %s -->", item;
    html_tag(item);
    text2html($0);
#    html_close(item);
    next;
}

/^ / && ($0 !~ /^[[:space:]]+</) {
#       printf "<!-- last TAG(%d)='%s'-->", TAG[0],TAG[TAG[0]];
    html_tag("pre");
    text2html(substr($0, 2));
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
    if (match($0, /<(code|nowiki|pre)[^>]*>/,ary)) {
	tag = tolower(ary[1]);
	# text before tag
	text = substr($0, 1, RSTART  -1);
	html = substr($0, RSTART, (tag != "nowiki") ? RLENGTH : 0);
	$0 = substr($0, RSTART + RLENGTH);

	if (trim(text)) {
            html_tag("p");
	    text2html(text);
	    printf "%s\n", html_debug("text before html");
	}
	html_tag((tag == "pre") ? "" : "p");
	if (tag == "nowiki") html_tag("tt");

	printf "%s", html;
	while(! match(tolower($0), "</" tag "[[:space:]]*>")) {
	    printf "%s%s\n", raw2html($0, 1), html_debug("html line");
	    if (getline <= 0) {
		printf "<span class='error'>error: missig /" tag " at " NR "</span><br>";
		break;
	    }
	    RAW = RAW $0 "\n";
	}
	if (RSTART) {
	    text = substr($0, RSTART + RLENGTH);
	    html = substr($0, RSTART, (tag != "nowiki") ? RLENGTH : 0);
	    $0 = substr($0, 1, RSTART -1);
	    printf "%s%s", raw2html($0, 1), html_debug("last html line");
	    if (tag == "nowiki") html_close("tt");
	    printf "%s", html;
	    if (trim(text)) {
		html_tag("p");
		text2html(text);
	    }
	}
    } else {
        html_tag("p");
	text2html($0);
#	printf "%s\n", html_debug("text end");
    }
    next;
}
// {
    html_tag("-"); # close the last tag
}
