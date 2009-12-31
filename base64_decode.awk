#! /usr/bin/gawk -f

BEGIN {
    BASE64 = digits("base64");
#    printf "%s\n", DIGITS;
}
function digits_range(min,max,  str,i) {
    str = "";
    for (i = min; i <= max; i++) str = str sprintf("%c", i);
    return str;
}
function asc(char,  digits,i) {
    digits = digits_range(0, 255);
    return ((i = index(digits, char)) > 0) ? i - 1 : "";
}
function digits(name) {
    if (name == "base64")
	return digits_range(asc("A"), asc("Z")) \
	       digits_range(asc("a"), asc("z")) \
	       digits_range(asc("0"), asc("9")) \
	       "+/";
    else if (name == "base32")
	return digits_range(asc("A"), asc("Z")) \
	       digits_range(asc("2"), asc("7"));
    else if (name == "base32hex")
	return digits_range(asc("0"), asc("9")) \
	       digits_range(asc("A"), asc("V"));
    else if (name == "base85")
	return digits_range(asc("0"), asc("9")) \
	       digits_range(asc("A"), asc("Z")) \
	       digits_range(asc("a"), asc("z")) \
	       "!" \
	       digits_range(asc("#"), asc("&")) \
	       digits_range(asc("("), asc("+")) \
	       "-" \
	       digits_range(asc(";"), asc("@")) \
	       "^_`" \
	       digits_range(asc("{"), asc("~"));
} 
#	printf "+ pos:%3d val:%3d bits=%3d ", i, b-1, bits;
#	for (x = 6*4-1; x >= 0; x --) {
#	    if ((6*4-1 -x) % 6 == 0) printf " ";
#	    printf "%s", (and(val, 2**x)) ? 1 : 0;
#	}
#	printf "\n";
function base_decode(str,digits,pad,  val,bits,i,b) {
    val = bits = 0;
    for (i = 1; i <= length(str); i ++) {
	if (! (b = index(digits pad, substr(str, i, 1)))) {
	    printf "unknown digit '%c'\n", substr(str, i, 1) > "/dev/stderr";
	    return "";
	    exit(2);
	}
	if (b > length(digits)) break;
	val = or(lshift(val, 6), b -1);
	bits += 6;
	
	if (bits >= 8) {
	    printf "%c", and(rshift(val, bits % 8), 255);
	    val = and(val, lshift(1, bits % 8) -1);
	    bits -= 8;
	}
    }
}

BASE64 {
    base_decode($0, BASE64, "=");
}
END {
    printf "\n";
}
