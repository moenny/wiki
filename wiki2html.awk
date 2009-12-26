#! /usr/bin/gawk -f

BEGIN {
    TABLE = 0;
    CREOLE_TABLE = 0;
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
    ELINKS[0] = 0;
    
    DOC = "";
    
    OPT["DEFAULT_DOC"] = "wiki";
    
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
		printf "Location: %s/%s\n\n", SELF, OPT["DEFAULT_DOC"];
		exit;
	    }
	    else if (match(ENVIRON["PATH_INFO"], /^\/([^\/*?]+)$/, ary)) {
		ARGC =1;
		DOC=ary[1];
		file = "";
	        if (! system("test -L " ary[1] " -a -w " ary[1])) RW = 1;
		
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
#    print "<!DOCTYPE html PUBLIC '-//W3C//DTD HTML 4.01 Transitional//EN' 'http://www.w3.org/TR/html4/loose.dtd'>";
    print "<!DOCTYPE html PUBLIC '-//W3C//DTD HTML 4.01//EN' 'http://www.w3.org/TR/html4/strict.dtd'>";
    html_tag("html");
    html_tag("head");
    html_tag("title");
    text2html(DOC);
    html_close("title");
#    printf "<link rel='stylesheet' media='screen' href='../wiki.css'>";

    print "\n  <meta http-equiv='Content-type' content='text/html;charset=UTF-8'>";

    printf "  <link rel='stylesheet' media='screen' type='text/css' href='../wiki.css'>";
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
    if (ENVIRON["SERVER_PROTOCOL"] ~ /^HTTP/ && TAG[0] && RW) {

	if (CGI["mode"] == "edit" || CGI["mode"] == "preview") {
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

    html_close("body");
    html_close("html");
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
    while (TAG[0] > 0 && TAG[TAG[0]] ~ /^(ol|ul)$/ && tag !~ /^(ol|ul|li)$/) {
        html_close();
        L_COUNT --;
    }

    printf "\n";
    i = TAG[0];
    while (i -- > 0) printf " ";

    if (attr) 
	attr = " " attr;
    else if (tag == "tr")
	attr = " class='" ((++TR_COUNT % 2) ? "even" : "odd") "'";

    printf "<%s%s>", TAG[++TAG[0]] = tag, attr;
}

function ary_index(ary, element, i) {
    i = 1;
    while (i <= ary[0] && ary[i] != element) i++;
#    if (i > ary[0]) ary[++ary[0]] = element;
#    for (i = 1; i <= 
    return i;
}
function text2html(str,  class, ary, left, start, e) {
    left = 0;
    gsub(/\r/, "", str);
    while (match(substr(str, left +1), /<ref[^>]*>/)) {
	start = left + RSTART + RLENGTH;
	left += RSTART -1;
	if (match(substr(str, left), /<\/ref[[:space:]]*\>/)) {
#	    REF[++REF[0]] = substr(str, start, left + RSTART -1 - start);
	    REF[0] = ary_index(REF, start = substr(str, start, left + RSTART -1 - start));
	    REF[REF[0]] = start;
	    str = substr(str, 1, left) \
		sprintf("<sup>[<a href='#_ref_%d' name='ref_%d' class='ref'>%d</a>]</sup>" \
		, REF[0], REF[0], REF[0]) \
		substr(str, left + RSTART + RLENGTH);
	}
    }
#    if (0)
    left = "";
    while ((e = match(str,/(^|[^\[])\[(http:\/\/[^[:space:]\]]+)([[:space:]]*([^\]]+))?(\])/, ary)) \
	  || match(str,/()\[\[([^\]|]+)(\|([^[\]]+))?\]\]/, ary) \
	  || match(str,/(^|[^'">])(http:\/\/[^[:space:]\]]+)/, ary) \
	   ) {
	if (ary[2] ~ /^#/) {
	    if (! ary[4]) ary[4] = substr(ary[2], 2);
	    ary[2] = "#" trim(substr(ary[2], 2), 1);
	    class = "local";
	} else if (ary[2] ~ /^[^\/]+$/) { # internal
	    if (f_readable(ary[2]) > 0)
		class = "intern";
	    else 
		class = "intern_missing";
	} else {
	    class = "extern";
	    if (e && !ary[4])  {
		ary[4] = "[" (ELINK[0] = ary_index(ELINKS, ary[2])) "]";
	    }
	}
	left = left substr(str,1, RSTART -1 + length(ary[1])) \
	    sprintf("<a href='%s' class='%s'>%s</a>" \
		    , ary[2], class, (ary[4]) ? ary[4] : ary[2]);
	str = substr(str, RSTART + length(ary[1])+ RLENGTH - length(ary[5]));
    }
    str = left str;
    gsub(/\\\\/, "<br>", str);
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

# Creole table
#! TABLE && 
! TABLE && match($0, /^\|/,ary) {
    str = substr($0, RSTART + RLENGTH);
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
	attr = (trim(text) ~ /^[0-9]+[0-9,']*(\.[0-9]+)([[:space:]].*|)$/) \
	    ?  "align='right' " : "";
	
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
TABLE && match($0, /^[[:space:]]*\|-/) {
    if (TR) {
	html_close("tr");
	TR --;
    }
    html_tag("tr");
    TR ++;
    next;
}
TABLE && match($0, /^[[:space:]]*\|\}/) {
    if (TR) {
	html_close("tr");
	TR --;
    }
    html_close("table");
    TABLE --;
    next;
}
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
        if (trim(text) ~ /^[0-9]+[0-9,']*(\.[0-9]+)([[:space:]].*|)$/)
	    attr = "align='right' " attr;
	
	html_tag(tag, attr);
	text2html(text);
	html_close(tag);
    }
    next;
}
#|=Heading Col 1 |=Heading Col 2         |
#|Cell 1.1       |Two lines\\in Cell 1.2 |
#|Cell 2.1       |Cell 2.2               |



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
	html_close();
    }

    html_tag("li");
    text2html($0);
    html_close("li");
    next;
}

match($0, /^ /) {
#       printf "<!-- last TAG(%d)='%s'-->", TAG[0],TAG[TAG[0]];
   if (TAG[0] == 0 || TAG[TAG[0]] != "pre") html_tag("pre");
   printf "%s\n", substr($0, RSTART + RLENGTH);
   next;
}
    
/[^[:space:]]/ {
    if (gsub(/^----/, ""))
	$0 = "<hr>" $0;

    if (match($0, /<(pre|table)[^>]*>/,ary)) {
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
