function cwmPosObj(o, x, y)
{
	if (o.style) o = o.style;
	o.left = x,
	o.top = y;
}
function cwmGetLayer(n)
{
	return document[n] || document.getElementById(n) || document.all[n];		
}
function cwmShowLayer(o, v)
{	
	(!o.style)
	? o.visibility = (v) ? 'show' : 'hide'
	: o.style.visibility = (v) ? 'visible' : 'hidden';
}
function cwmMouseMove(e)
{
        mx = (e) ? e.pageX: event.x + window.document.body.scrollLeft;
        my = (e) ? e.pageY: event.y + window.document.body.scrollTop;
        if (move) move(); 
}
function cwmPosShow(n,x,y,z)
{
        var o = cwmGetLayer(n);
        cwmPosObj(o, x, y);
        cwmShowLayer(o, 1);
        //cwmGetLayerImage(fstPointerLyr + 0).src = cwm[fstPointerImg + 6].src;
}
function cwmLayerScrollToY(n,y,cy,cyy)                  // 2001-06-14
{
        var t = cwmGetLayer(n);

        if (! t.style)
        {
                t.top = y;
                t.clip.top = cy;
                t.clip.bottom = cyy;
        }
        else
        {
                t.style.clip = 'rect(' + cy + ' auto ' + cyy + ' auto)';
                t.style.top = y;
        }
}
function scrollYoffset() {
    return window.pageYOffset ||
	(document.documentElement) 
	? document.documentElement.scrollTop
	: document.body.scrollTop
	;
}
function abs_y(o) {
    y =  o.offsetTop;
    while (o = o.offsetParent) y += o.offsetTop;
    return y;
}
var last_to;
function toc_mark() {
    str = "";
    ypos = scrollYoffset();
    po = document.getElementsByTagName('a');
    yy=0;
    for (i = 0; i < po.length; i++)
	if (po[i].className == "head" && po[i].name) {
	    if (abs_y(po[i]) >= ypos) {
		if ((to = cwmGetLayer("TOC")) &&
		    (to = to.getElementsByTagName('a'))) {
		    for (c = 0; c < to.length ; c ++)
			if ((to[c].href) && to[c].href == po[i].href) {
			    if (last_to) last_to.className = "toc";
			    (last_to = to[c]).className = "in_toc";
			}
		}
		return ;
	    }
	}
}
function toc_close() {
    cwmShowLayer(cwmGetLayer("TOC"),0);
    cwmShowLayer(cwmGetLayer("TOC_CLOSED"), 1);
}
function toc_open() {
    cwmShowLayer(cwmGetLayer("TOC"), 1);
    cwmShowLayer(cwmGetLayer("TOC_CLOSED"), 0);
}
function toc(t, i) {
//    t = cwmGetLayer("TOC"); 
    t.style.opacity = (i) ? .75 : .25;
    t.style.filter = "alpha(opacity=" + ((i) ? .75 : .25) * 100 + ")";
}
function init() {
    toc_mark();
    toc(cwmGetLayer("TOC"),0); 
}

window.onscroll = toc_mark;
window.onresize = toc_mark;
window.onload = init;

