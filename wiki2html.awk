#! /usr/bin/gawk -f
#
# Copyright (c) 2009 Christian W. Moenneckes
#
# vim:sts=4:ts=8

BEGIN {
    OPT["DEFAULT_DOC"] = "toc";
    OPT["USE_SYMLINK"] = 1;
    OPT["MAX_DEBUG"]   = 2;
    OPT["ALLOW_EDIT"]  = 1;
    OPT["TMP_PREFIX"]  = "/tmp/wiki-draft-";
    OPT["PROC_UPTIME"] = "/proc/uptime";
    OPT["CSS_SCREEN"]  = "../wiki.css";
    OPT["DOC_DIR"]     = "wikidocs";
    OPT["DRAFT_VIEW"]  = 1;

    UPTIME = uptime();
    
    TABLE = 0;
    CREOLE_TABLE = 0;
    TR = 0;
    TD = 0;
    TAG[0] = 0;
    RAW = "";
    SELF = "";
    RW = 0;
    TR_COUNT = 0;

    OL_COUNT = 0;
    L_COUNT = 0;
    
    REF[0] = 0;
    ELINKS[0] = 0;
    
    DOC = "";
    
    DST_FILE = "";
    SRC_FILE = "";

    CGI[0] = 0;

    if (ENVIRON["SERVER_PROTOCOL"] ~ /^HTTP/) {
	
	if (OPT["DOC_DIR"] !~ /^\// \
	    && match(ENVIRON["SCRIPT_FILENAME"], /^(.*\/)([^\/]+)$/, ary))
	    OPT["DOC_DIR"] = ary[1] OPT["DOC_DIR"];
	
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
	    exit;
	} else if (match(ENVIRON["PATH_INFO"], /^\/([a-zA-Z0-9_-]+)$/, ary) \
		&& 3 <= RLENGTH -1 && RLENGTH <= 32 \
		) {
	    ARGC =1;
	    DOC = gensub(/_/, " ", "g", docfile = ary[1]);

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
		    exit;
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
		    exit;
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
    html_tag("title");
    text2html(((CGI["mode"]) ? "" CGI["mode"] ":" : "") DOC);
    html_close("title");

    html_tag("meta", "http-equiv='Content-type' content='text/html;charset=UTF-8'");

    if (CGI["refresh"] && ! CGI["mode"])
	html_tag("meta", "http-equiv='refresh' content='7'");

    if (OPT["CSS_SCREEN"])
	html_tag("link", sprintf("rel='stylesheet' media='screen' type='text/css' href='%s'", OPT["CSS_SCREEN"]));

    html_tag();
    html_tag("body");
    if (errstr) {
	printf "<p class='error'>%s</p>\n", errstr;
	exit;
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
	    exit;
	}
	cmd = "LANG=C diff -uw " SRC_FILE " " DST_FILE;

	html_tag("table");
	line = 0;
	src_row[0] = 0;
	src_ptr = 1;
	src_start = 0;
	html_tag("tr");
	html_tag("th", "colspan='2'");
	printf "current version";
	html_close("th");
	html_tag("th", "colspan='2'");
	printf "draft version";
	html_close("th");
	html_close("tr");
	while (( cmd | getline) > 0) {
	    if (++line <= 2) {
		;
	    } else if ($0 !~ /^[ \+\-]/) {
	        html_tag("tr");
	        html_tag("td", "colspan='4' align='center'");
		if (match($0, /^@@ -([0-9]+),([0-9]+) \+([0-9]+),([0-9]+) @@/, ary)) {
		    src_start = ary[1];
		    dst_start = ary[3];

		    print "...";
		} else {
		    printf "<code>%s</code>\n", $0;
		}
	        html_close("td");
	        html_close("tr");
	        src_row[0] = 0;
	        src_ptr = 1;
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
				print "<td colspan='2'></td>";
				html_close("tr");
				html_tag("tr");
			    }
			}
			if (c == "+") dst_class = "diff_mod";
		    } else if (c == "+") {
			print "<td colspan='2'></td>";
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
		print "<td colspan='2'></td>";
		html_close("tr");
	    }
	} else if (c != "+") {
	    html_tag("tr");
	    html_tag("td", "colspan='4' align='center'");
	    print "...";
	    html_close("td");
	    html_close("tr");
	}
	
	html_close("table");
	exit;
    }
}
END {
    if (CGI["mode"] ~ /^(save|discard)$/) exit;
#    if (TAG[0] > 0 && TAG[TAG[0]] ~ /^(pre)$/) html_tag("");

    if (REF[0] && TAG[0]) {
	html_tag("h2");
	text2html("References");
	html_close("h2");

	html_tag("ol"); # ul
	for (i = 1; i <= REF[0]; i ++) {
	    html_tag("li");
	    printf "<a href='#ref_%d' name='_ref_%d' class='ref'>&uarr;</a> " \
		, i, i;
	    text2html(REF[i]);
	    html_close("li");
	}
	html_close("ol");
    }
    html_tag("hr"); # DUMMY

    if (ENVIRON["SERVER_PROTOCOL"] ~ /^HTTP/ && TAG[0]) {

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
	    printf "</div>\n";
	    printf "</form>";
	} else {
	    printf ("<div style='width:100%;' class='tool'>");
	    printf "<a href='%s?mode=' class='tool'>toc</a>\n", SELF;

	    printf "<a href='?mode=' class='tool'>reload</a>\n";
	    
	    if (SRC_FILE)
	        printf "<a href='?mode=source' class='tool'>source</a>\n";
	    
	    if (DST_FILE && OPT["DRAFT_VIEW"]) {
	        printf "<a href='?mode=draft' class='tool'>draft</a>\n";
		if (SRC_FILE) 
		    printf "<a href='?mode=diff-draft' class='tool'>diff-draft</a>\n";
		if (RW) 
		    printf "<a href='?mode=edit-draft' class='tool'>edit-draft</a>\n";
	    } else if (RW)
		printf "<a href='?mode=edit#edit' class='tool'>edit</a>\n";
	    printf "</div>\n";
	}

	if (UPTIME) {
	    printf("<hr><i>%s (-%.2fs)</i>" \
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
    html_tag("th", (class = "class='" class "'") " align='right'");
    printf "%d", row;
    html_close("th");
		
    html_tag("td", class);
    printf "<code>%s</code>\n",text;
    html_close("td");
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
function html_close(tag, i, t) {
    if (TAG[0] <= 0) {
	printf "<span class='error'>no more html tags to close</span>"; 
	return;
    }

    t = TAG[0];
    if (tag) 
	while (t > 0 && TAG[t] != tag) {
	    if (t != TAG[0]) 
		printf "<span class='error'>&lt;%s&gt;</span>", TAG[t];
	    t --;
	}
	
    
    if (TAG[TAG[0]] !~ /^(a|h[1-9]|li|pre|title)$/) {
        printf "\n";
        i = TAG[0]-1;
        while (i -- > 0) printf " ";
    }

    if (t < TAG[0])
	printf "<span class='error'>closing %d tags to &lt;%s&gt;</span>" \
	    , TAG[0] -t, TAG[TAG[0]];
   
    while (TAG[0] >= t) printf "</%s>", TAG[TAG[0]--];
}
function html_tag(tag,attr, i) {
    if (!tag)  return html_close();
    
    if (TAG[0] > 0 && TAG[TAG[0]] ~ /^(pre)$/) html_close("pre");
    while (TAG[0] > 0 && TAG[TAG[0]] ~ /^(dl|ol|ul)$/ && tag !~ /^(dl|dt|dd|ol|ul|li)$/) {
        html_close();
        L_COUNT --;
    }

    printf "\n";
    i = TAG[0];
    while (i -- > 0) printf " ";

    if (attr = trim(attr)) 
	attr = " " attr;
    else if (tag == "tr")
	attr = " class='" ((++TR_COUNT % 2) ? "even" : "odd") "'";

    if (tag !~ /^(br|hr|link|meta)$/) TAG[++TAG[0]] = tag;
    printf "<%s%s>", tag, attr;
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
    else if (trim(text) ~ /^[[:space:]]*[0-9]+[0-9,']*(\.[0-9]+)([[:space:]].*|)$/)
	return "right";

}
function raw2html(str, full) {
    gsub(/\&/, "\\&amp;", str);

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
function text2html(str,  class, ary, left, start, e) {

    gsub(/\r/, "", str);

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

    # checking links
    left = "";
    while ((e = match(str,/(^|[^\[])\[(http:\/\/[^[:space:]\]]+)([[:space:]]*([^\]]+))?(\])/, ary)) \
	  || match(str,/()\[\[([^\]\|]+)(\|([^\]]+))?\]\]/, ary) \
	  || match(str,/(^|[^'">])(http:\/\/[^[:space:]\]]+)/, ary) \
	   ) {
	if (ary[2] ~ /^#/) {
	    if (! ary[4]) ary[4] = substr(ary[2], 2);
	    ary[2] = "#" trim(substr(ary[2], 2), 1);
	    class = "local";
	} else if (ary[2] ~ /^[^\/]+$/) { # internal
	    if (! ary[4]) ary[4] = ary[2];
	    gsub(/ /, "_", ary[2]);
	    if (f_readable(OPT["DOC_DIR"] "/" ary[2]) > 0)
		class = "intern";
	    else 
		class = "intern_missing";
	} else {
	    class = "extern";
	    if (e && !ary[4])  {
		ary[4] = "[" (e = ary_index(ELINKS, ary[2])) "]";
		if (ELINKS[0] < e) ELINKS[0] = e;
	    }
	}
	left = left substr(str,1, RSTART -1 + length(ary[1])) \
	    sprintf("<a href='%s' class='%s'>%s</a>" \
		    , ary[2], class, (ary[4]) ? ary[4] : ary[2]);
	str = substr(str, RSTART + length(ary[1]) + RLENGTH);
    }
    str = left str;

    # creole linebreak
    gsub(/\\\\/, "<br>", str);
    
    printf "%s", formating(raw2html(str));
#    printf "%s", (left str);
}
function trim(str, f) {
    gsub(/^[[:space:]]+/, "", str);
    gsub(/[[:space:]]+$/, "", str);
    if (f) gsub(/[[:space:]]+/, "_", str);
    return str;
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
	CREOLE_TABLE = 1;
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
    html_tag("h" h, "id='" trim(text,1) "'");
    text2html(text);
    html_close("h" h);
    next;
}

# MediaWiki table
match($0,/\{\|/) {
    attr = substr($0, RSTART + RLENGTH);
    text2html(substr($0,1, RSTART-1));
    html_tag("table", attr);
    TABLE ++;
    next;
}
# .. row
TABLE && match($0, /^[[:space:]]*\|-/) {
    attr = substr($0, RSTART + RLENGTH);
    if (TR) {
	html_close("tr");
	TR --;
    }
    html_tag("tr", attr);
    TR ++;
    next;
}
# .. end
TABLE && match($0, /^[[:space:]]*\|\}/) {
    if (TR) {
	html_close("tr");
	TR --;
    }
    html_close("table");
    TABLE --;
    next;
}
# .. cell
TABLE && match($0,/^[[:space:]]*([\|!])/,ary) {
    tag = (ary[1] == "!") ? "th" : "td";
    str = substr($0, RSTART + RLENGTH);
    if (! TR) {
	html_tag("tr");
	TR ++;
    }
    str = str ary[1] ary[1];
    while ((i = index(str, ary[1] ary[1])) > 0) {
	text = substr(str, 1, i -1);
	str = substr(str, i +2);
	attr = (i = index(text, "|")) ? substr(text, 1, i -1) : "";
	text = substr(text, i +1);

	if (! attr && (attr = detect_align(text))) attr = "align='" attr "'";
	
	html_tag(tag, attr);
	text2html(text);
	html_close(tag);
    }
    next;
}
# unordered-, ordered- and definition list
match($0, /^([#;:]+)/) || ($0 ~ /^\*/ && match(formating($0), /^(\*+)/)) {
    list = substr($0,RSTART + RLENGTH-1,1);
    if (list == "*") {
	list = "ul";
	item = "li";
    } else if (list == "#")  {
	list = "ol";
	item = "li";
    } else if (list == ";") {
	list = "dl";
	item = "dt";
    } else if (list == ":") {
	list = "dl";
	item = "dd";
    }
    $0 = substr($0, RSTART + RLENGTH);
    c = RLENGTH;
    for (i = 1 + L_COUNT; i <= c; i++) {
	html_tag(list);
	L_COUNT ++;
    }
    while (L_COUNT > c) {
	L_COUNT --;
	html_close();
    }

    html_tag(item);
    text2html($0);
    html_close(item);
    next;
}

match($0, /^ /) {
#       printf "<!-- last TAG(%d)='%s'-->", TAG[0],TAG[TAG[0]];
   if (TAG[0] == 0 || TAG[TAG[0]] != "pre") html_tag("pre");
   text2html(substr($0, RSTART + RLENGTH));
   printf "\n";
   next;
}
    
/[^[:space:]]/ {
    if (gsub(/^----/, ""))
	$0 = "<hr>" $0;

    if (match($0, /<(code|pre|table)[^>]*>/,ary)) {
	text = substr($0, 1, RSTART -1);
	tag = toupper(ary[1]);
	$0 = substr($0, RSTART);

	if (trim(text)) {
            html_tag("p");
	    text2html(text);
	}
	while(! match(toupper($0), "</" tag "[[:space:]]*>")) {
	    print $0;

	    if (getline <= 0) {
		printf "<span class='error'>error: missig /" tag " at " NR "</span>";
		break;
	    }
	    RAW = RAW $0 "\n";
	}
	print $0;
	if (trim(text)) html_close("p");
    } else {
        html_tag("p");
	text2html($0);
        html_close("p");
    }
    next;
}
