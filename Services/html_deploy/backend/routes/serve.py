import re
from fastapi import APIRouter, Request, HTTPException
from fastapi.responses import HTMLResponse
from backend.services import meta, gdrive, gcs
from backend.auth import require_session

router = APIRouter()

_CSP = (
    "default-src 'self' 'unsafe-inline' 'unsafe-eval' data: blob: https:; "
    "frame-ancestors 'self';"
)

# Injected into every served HTML — adds hoverable # anchor buttons on headings
# and postMessages the parent Viewer when clicked, enabling deep-link URLs.
_ANCHOR_SCRIPT = """
<script>
(function(){
var s=document.createElement('style');
s.textContent='.__ma-a{display:inline-block;margin-left:6px;font-size:.6em;color:#aaa;cursor:pointer;opacity:0;vertical-align:middle;transition:opacity .15s;user-select:none}'
+'h1:hover .__ma-a,h2:hover .__ma-a,h3:hover .__ma-a,h4:hover .__ma-a{opacity:1}'
+'.__ma-a:hover{color:#1a73e8}';
document.head.appendChild(s);
var seen={};
document.querySelectorAll('h1,h2,h3,h4').forEach(function(h){
  if(!h.id){
    var slug=h.textContent.trim().toLowerCase().replace(/[^a-z0-9]+/g,'-').replace(/^-+|-+$/g,'').slice(0,60)||'section';
    var base=slug,n=1;
    while(seen[slug])slug=base+'-'+(++n);
    seen[slug]=1;h.id=slug;
  } else { seen[h.id]=1; }
  var b=document.createElement('span');
  b.className='__ma-a';b.textContent='#';b.title='Copy section link';
  b.addEventListener('click',function(e){
    e.stopPropagation();
    window.parent.postMessage({type:'mosaic-copy-link',anchor:h.id},'*');
  });
  h.appendChild(b);
});
window.addEventListener('message',function(e){
  if(e.data&&e.data.type==='mosaic-scroll-to'){
    var el=document.getElementById(e.data.anchor);
    if(el)el.scrollIntoView({behavior:'smooth',block:'start'});
  }
});
if(window.location.hash){
  var el=document.getElementById(window.location.hash.slice(1));
  if(el)setTimeout(function(){el.scrollIntoView({behavior:'smooth',block:'start'});},50);
}
})();
</script>
"""

_BODY_RE = re.compile(r'</body>', re.IGNORECASE)
_HTML_RE = re.compile(r'</html>', re.IGNORECASE)


def _inject_anchors(html: str | bytes) -> str:
    if isinstance(html, bytes):
        html = html.decode('utf-8', errors='replace')
    for pat in (_BODY_RE, _HTML_RE):
        m = pat.search(html)
        if m:
            return html[:m.start()] + _ANCHOR_SCRIPT + html[m.start():]
    return html + _ANCHOR_SCRIPT


@router.get("/api/serve/{report_id}", response_class=HTMLResponse)
async def serve_report(request: Request, report_id: str):
    session = require_session(request)
    data = meta.get_report(report_id)
    if not data:
        raise HTTPException(status_code=404, detail="Report not found")

    # Privacy check: block non-owners from accessing private category content
    cat = meta.get_category(data["category_id"])
    if cat and cat.get("is_private") and cat.get("created_by") != session["email"]:
        raise HTTPException(status_code=404, detail="Report not found")

    source_type = data["source_type"]
    source_ref = data["source_ref"]

    if source_type == "gdrive":
        if gcs.cache_exists(report_id):
            html = gcs.read_cache(report_id)
        else:
            try:
                html = gdrive.fetch_html(source_ref)
            except Exception as e:
                raise HTTPException(status_code=502, detail=f"Failed to fetch from Google Drive: {e}")
            gcs.write_cache(report_id, html)
    elif source_type == "upload":
        try:
            html = gcs.read_upload(report_id)
        except Exception as e:
            raise HTTPException(status_code=502, detail=f"Failed to read uploaded file: {e}")
    else:
        raise HTTPException(status_code=400, detail="Unknown source type")

    return HTMLResponse(
        content=_inject_anchors(html),
        headers={
            "X-Frame-Options": "SAMEORIGIN",
            "Content-Security-Policy": _CSP,
        },
    )
