#! /usr/bin/gawk -f

BEGIN {
    TABLE = 0;
    TR = 0;
    TD = 0;
    TAG[0] = 0;
    RAW = "";
    CGI["debug"] = 0;
    SELF = "";
    RW = 0;
    TR_COUNT = 0;

    OL_COUNT = 0;
    L_COUNT = 0;
    
    REF[0] = 0;
    DOC = "";
    if (ENVIRON["SERVER_PROTOCOL"] ~ /^HTTP/) {
	SELF = "http://" ENVIRON["SERVER_NAME"] ENVIRON["SCRIPT_NAME"]
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
		    CGI[a[1]] = decode(a[2]);
	    }


	    if (! ENVIRON["PATH_INFO"]) {
		printf "Location: %s/text\n\n", SELF;
		exit;
	    }
	    else if (match(ENVIRON["PATH_INFO"], /^\/([^\/*?]+)$/, ary)) {
		ARGC =1;
		DOC=ary[1];
		file = "";
	        if (! system("test -L "ary[1])) RW = 1;
		
		# FIXME: allow create docs ?
		if ((stat = f_readable(ary[1])) <0) {
		    RW  = 2; 
		    if (CGI["mode"] == "edit" && ! CGI["txt"]) 
			CGI["txt"] = "= " DOC " =";
		}
		
		if (RW && CGI["mode"] == "preview") {
		    file = sprintf("/tmp/%s-preview",ary[1]);
		} else if (RW && CGI["mode"] == "save") {
		    file = ary[1]
		    system(sprintf("ln -sfn %s%s %s" \
			   , file, strftime("-%Y%m%d-%H%M%S"), file));
		} else if (stat > 0) {
		    ARGV[ARGC++] = ary[1];
		} else {
#		    errstr = "nix doc";
		    file = sprintf("/tmp/%s-preview",ary[1]);
	        }
		if (file) {
		    print CGI["txt"] > file;
		    close(file);
		    ARGV[ARGC++] = file;
		} 
	    } else
		errstr = sprintf("Document not found: %s\n",ENVIRON["PATH_INFO"]);
	printf "Content-Type: text/html\n\n";
    }
    
    html_tag("html");
    html_tag("head");
#    printf "<link rel='stylesheet' media='screen' href='../wiki.css'>";
    printf "<title>%s</title>", DOC;
    printf "<link rel='stylesheet' media='screen' type='text/css' href='../wiki.css'>";
    html_tag();
    html_tag("body");
    if (errstr) {
	print errstr;
	exit;
    }

    print "<pre>";
#    printf "%s:%s\n",ARGC,ARGIND;
#    for (v in CGI) printf "%s='%s'\n", v, CGI[v];
    if (CGI["debug"] > 0) system("env");
    print "</pre>";
}
END {
    if (TAG[0] > 0 && TAG[TAG[0]] ~ /^(pre)$/) html_tag("");
    if (REF[0] && TAG[0]) {
	
	#print "<hr>";
	html_tag("h2");
	text2html("References");
	html_tag();

	html_tag("ol"); # ul
	for (i = 1; i <= REF[0]; i ++) {
	    printf "<li><a href='#ref_%d' name='_ref_%d' class='ref'>&uarr;</a> " \
		, i, i;
	    text2html(REF[i]);
	    printf "</li>";
	}
	html_tag();
	
    }
    if (ENVIRON["SERVER_PROTOCOL"] ~ /^HTTP/ && TAG[0] && RW) {

	if (CGI["mode"] == "edit" || CGI["mode"] == "preview") {
	    if (CGI["mode"] == "edit") CGI["txt"] = RAW;
	    printf "<a name='edit'></a>";
	    printf "<form method='POST' action='%s%s'>" \
		    , ENVIRON["SCRIPT_NAME"] \
		    , ENVIRON["PATH_INFO"] \
		    ;
	    printf "<textarea style='width:100%;height:50%' name='txt'>%s</textarea>",CGI["txt"];
	    printf ("<div style='width:100%;' class='tool'>");
	    printf "<input type='submit' name='mode' value='preview' class='tool'>";
	    printf "<input type='submit' name='mode' value='save' class='tool'>";
	    printf "<input type='submit' name='mode' value='cancel' class='tool'>";
	    printf "</div>\n";
	    printf "</form>";
	} else {
	    printf ("<div style='width:100%;' class='tool'>");
	    printf "<a href='%s?mode=' class='tool'>toc</a>", SELF;
	    printf "<a href='?mode=edit#edit' class='tool'>edit</a>";
	    printf "<a href='?mode=' class='tool'>reload</a>";
	    printf "<a href='?mode=source' class='tool'>source</a>";
	    printf "</div>\n";
	}
    }

    html_tag();
    html_tag();
}
function f_readable (file, c) {
    if (file ~ /^\/dev\/std(out|err)/) return 0;
    if (file ~ /[\/\?\*]/) exit; # FIXME ?
    c = getline < (file);
    close(file);
    return c;
}           
#
function decode(str,i,c) {
    #ac%0D%0Aid
#    return str;
#    str=sprintf("ac\nid%0Aba");
#    str=sprintf("ac%%2Bid%2Bba");
    i = 1;
    c = 0;
    gsub(/\+/, " ", str)
#    printf "<'%s'>\n",str >> "/dev/stderr";
    while (match(substr(str, i), /(%[0-9a-fA-F][0-9a-fA-F])/)) {
#	printf "!! ..%s\n",substr(str,i) >> "/dev/stderr";
	i += RSTART-1;
#	printf " !! %s[%s](%s)\n", substr(str,0,i-1),i-1,substr(str,i , RLENGTH -1) >> "/dev/stderr";
	str = substr(str,1, i-1) \
	    sprintf("%c", strtonum("0x" substr(str,i+1 , RLENGTH -1))) \
	    substr(str, i +RLENGTH);
#	gsub(/\r/, "",str);

	#RLENGTH-1;
	c++;
#	printf "<'%s'>%s[%d]\n\n",str,substr(str,i),RLENGTH >> "/dev/stderr";
    }
    return str;
}
function html_tag(tag,attr, i) {
    if (tag) {
	if (TAG[0] > 0 && TAG[TAG[0]] ~ /^(pre)$/) html_tag("");
	while (TAG[0] > 0 && TAG[TAG[0]] ~ /^(ol|ul)$/ && tag !~ /^(ol|ul)$/) {
	    html_tag("");
	    L_COUNT --;
	}

	printf "\n";
	i = TAG[0];
	while (i -- > 0) printf " ";
	if (attr)
	    attr = " " attr;
#	else if (tag ~ /h[1-5]/)  # FIXME: ?
#	    attr = " "
	    
        printf "<%s%s>", TAG[++TAG[0]] = tag, attr;

    } else if (TAG[0] > 0) {
        printf "</%s>", TAG[TAG[0]--];
    }
}
function text2html(str, ary, class) {

    while (match(str,/\[\[([^\]|]+)(\|([^[\]]+))?\]\]/,ary) \
	   || match(str,/\[(http:\/\/[^ ]+)( *([^\]]+))?\]/,ary) \
	   ) {
	if (ary[1] ~ /^#/) {
	    if (! ary[3]) ary[3] = substr(ary[1],2);
	    ary[1] = "#" trim(substr(ary[1],2), 1);
	    class = "local";
	} else if (ary[1] ~ /^[^\/]+$/) { # internal
	    if (f_readable(ary[1]) > 0)
		class = "intern";
	    else 
		class = "intern_missing";
	} else {
	    class = "extern";
	}
	str = substr(str,1, RSTART -1) \
	    sprintf("<a href='%s' class='%s'>%s</a>" \
		    , ary[1], class, (ary[3]) ? ary[3] : ary[1]) \
	    substr(str, RSTART+RLENGTH);
    }
    printf "%s", str;
}
function trim(str, f) {
    gsub(/^[[:space:]]+/, "", str);
    gsub(/[[:space:]]+$/, "", str);
    if (f) gsub(/[[:space:]]+/, "_", str);
    return str;
}
// {
    RAW = RAW $0 "\n"; 
    if (CGI["debug"]) printf "<!-- %s -->", $0;
    if (CGI["mode"] == "source") {
	if (TAG[0] == 0 || TAG[TAG[0]] != "pre") html_tag("pre");
	gsub(/\&/, "\\&amp;");
	gsub(/</, "\\&lt;");
	gsub(/>/, "\\&gt;");
        print $0;
	next;
    }
}
match($0, /^(=+)([^=]+)(=+)/, ary) {
    h = length(ary[length(ary[1]) >= length(ary[3]) ? 1 : 3]);
    text = substr(ary[1], h +1) ary[2] substr(ary[3], h +1);
    html_tag("h" h, "id='" trim(text,1) "'");
    text2html(text);
    html_tag();
    next;
}
match($0,/\{\|/) {
    text2html(substr($0,1, RSTART-1));
    html_tag("table");
    TABLE ++;
    next;
}
TABLE && match($0,/^[[:space:]]*\|-[[:space:]]*$/) {
    if (TR) print "</tr><tr>";
    next;
}
TABLE && match($0, /^[[:space:]]*\|\}/) {
#//    print "</table>";
    html_tag();
    TABLE --;
    next;
}
TABLE && match($0,/^[[:space:]]*([\|!])/,ary) {
    tag = (ary[1] == "!") ? "th" : "td";
    str = substr($0, RSTART + RLENGTH);
#    printf "#rest:%s\n", ary[1]; #str;
    if (! TR) printf("<tr class='%s'>",(++TR_COUNT % 2) ? "even" : "odd");
    while ((i = index(str, ary[1] ary[1])) > 0) {
#	printf "# %d\n", i;
	html_tag(tag);
	text2html(substr(str,0, i-1));
	html_tag();
	str = substr(str, i +2);
    }
    html_tag(tag);
    text2html(str);
    html_tag();
    if (! TR) printf("</tr>");
    printf("\n");
    next;
}
match($0, /^([#\*]+)/) {
    tag = (substr($0,RSTART + RLENGTH-1,1) == "*") ? "ul" : "ol";
    $0 = substr($0, RSTART + RLENGTH);
    c = RLENGTH;
    for (i = 1 + L_COUNT; i <= c; i++) {
	html_tag(tag);
	L_COUNT ++;
    }
    while (L_COUNT > c) {
	L_COUNT --;
	html_tag();
    }
	
    printf "<li>";
    text2html($0);
    printf "</li>\n";
    next;
}

match($0, /^ /) {
#       printf "<!-- last TAG(%d)='%s'-->", TAG[0],TAG[TAG[0]];
   if (TAG[0] == 0 || TAG[TAG[0]] != "pre") html_tag("pre");
   printf "%s\n", substr($0, RSTART + RLENGTH);
   next;
}
    
/[^[:space:]]/ {
    if (match($0, /<(pre|table|ref)[^>]*>/,ary)) {
	text = substr($0, 1, RSTART -1);
	if ((tag = toupper(ary[1])) == "REF") {
	    REF[0]++;
	    $0 = substr($0, RSTART + RLENGTH);
	} else {
	    $0 = substr($0, RSTART);
        }

	if (text !~ /^[[:space:]]$/) {
            html_tag("p");
	    text2html(text);
	}
	while(! match(toupper($0), "</" tag "[[:space:]]*>")) {
	    if (tag == "REF")
		REF[REF[0]] = REF[REF[0]] substr($0, 1, RSTART -1);
	    else
	        print $0;

	    if (getline <= 0) {
		printf "<span style='color:red'>error: missig /" tag " at " NR "</span>";
		break;
	    }
	    RAW = RAW $0 "\n"; 
	}
	if (RSTART && tag == "REF") {
	    REF[REF[0]] = REF[REF[0]] substr($0, 1, RSTART-1);
	    printf "<sup>[<a href='#_ref_%d' name='ref_%d' class='ref'>%d</a>]</sup>%s" \
		, REF[0], REF[0], REF[0], substr($0, RSTART + RLENGTH);
	} else {
	    print $0;
	}
	if (text) html_tag(); # /p
    } else {
        html_tag("p");
	text2html($0);
        html_tag();
    }
    next;
}
