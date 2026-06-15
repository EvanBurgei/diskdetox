// Cloudflare Pages Function — runs on every request.
// Redirect the www host to the apex (canonical) host; everything else falls through
// to normal static-asset serving via next(), so _headers (CSP) and 404.html still apply.
// (Pages `_redirects` can't do this — it matches on path only, not hostname.)
export async function onRequest(context) {
  const { request, next } = context;
  const url = new URL(request.url);
  if (url.hostname === "www.diskdetox.com") {
    url.hostname = "diskdetox.com";
    return Response.redirect(url.toString(), 301);
  }
  return next();
}
