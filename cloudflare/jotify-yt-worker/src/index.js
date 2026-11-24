/**
 * Jotify shared YouTube search gateway.
 * Only YouTube Data API metadata. Never streams/extracts audio or hides videos.
 * Set YOUTUBE_API_KEY as a Cloudflare secret, not in GitHub or Android.
 */
const VID = /^[a-zA-Z0-9_-]{11}$/;
const LIST = /^[a-zA-Z0-9_-]{8,120}$/;
const TTL = 900;

function respond(body, status=200, cache=false) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': cache ? 'public, max-age='+TTL : 'no-store',
      'X-Content-Type-Options': 'nosniff',
      'Referrer-Policy': 'no-referrer'
    }
  });
}
const shorten=(value,max=210)=>String(value??'').slice(0,max);
function thumb(sn) {
  const value=sn?.thumbnails?.medium?.url??sn?.thumbnails?.default?.url??'';
  return typeof value==='string'&&value.startsWith('https://')?value.slice(0,600):'';
}
async function fetchGoogle(url,env) {
  // Do not log Google URL (includes credential), raw response, or API secret.
  url.searchParams.set('key',env.YOUTUBE_API_KEY);
  const ctrl=new AbortController();
  const timer=setTimeout(()=>ctrl.abort(),11000);
  try {
    const response=await fetch(url,{headers:{Accept:'application/json'},signal:ctrl.signal});
    const body=await response.json();
    if(!response.ok){
      const detail=Array.isArray(body?.error?.details)
        ?body.error.details.find(x=>typeof x?.reason==='string'):null;
      const reason=String(detail?.reason??body?.error?.errors?.[0]?.reason??'googleError');
      const safe=/^[a-zA-Z0-9_.-]{1,60}$/.test(reason)?reason:'googleError';
      const quota=/quota|limit|rate/i.test(safe)||response.status===429;
      return {error:respond({
        status:'failure',
        error:quota?'YT search quota reached. Try again later.':'YouTube service temporarily unavailable.',
        googleReason:safe
      },quota?429:503)};
    }
    return {body};
  }catch(_){
    return {error:respond({status:'failure',error:'Cannot reach YouTube right now.'},502)};
  }finally{clearTimeout(timer);}
}
async function search(url,env){
  const q=shorten(url.searchParams.get('q'),121).trim().replace(/\s+/g,' ');
  const kind=url.searchParams.get('kind')||'song';
  if(q.length<2||q.length>120||!['song','playlist'].includes(kind))
    return {error:respond({status:'failure',error:'Enter a valid song or playlist query.'},400)};
  const dest=new URL('https://www.googleapis.com/youtube/v3/search');
  dest.search=new URLSearchParams({
    part:'snippet',type:kind==='playlist'?'playlist':'video',
    q,maxResults:'15',safeSearch:'moderate'
  }).toString();
  if(kind==='song')dest.searchParams.set('videoEmbeddable','true');
  const fetched=await fetchGoogle(dest,env);
  if(fetched.error)return fetched;
  const items=(Array.isArray(fetched.body.items)?fetched.body.items:[]).map(row=>({
    kind,id:kind==='playlist'?row?.id?.playlistId:row?.id?.videoId,
    title:shorten(row?.snippet?.title,220),
    channel:shorten(row?.snippet?.channelTitle,140),
    thumbnail:thumb(row?.snippet)
  })).filter(row=>kind==='playlist'?LIST.test(row.id):VID.test(row.id));
  return {result:{status:'ok',kind,items}};
}
async function playlist(url,env){
  const id=url.searchParams.get('list')||'';
  if(!LIST.test(id))
    return {error:respond({status:'failure',error:'Invalid playlist ID.'},400)};
  const dest=new URL('https://www.googleapis.com/youtube/v3/playlistItems');
  dest.search=new URLSearchParams({part:'snippet',playlistId:id,maxResults:'30'}).toString();
  const fetched=await fetchGoogle(dest,env);
  if(fetched.error)return fetched;
  const items=(Array.isArray(fetched.body.items)?fetched.body.items:[]).map(row=>({
    id:row?.snippet?.resourceId?.videoId,
    title:shorten(row?.snippet?.title,220),
    channel:shorten(row?.snippet?.videoOwnerChannelTitle??row?.snippet?.channelTitle,140),
    thumbnail:thumb(row?.snippet)
  })).filter(row=>VID.test(row.id));
  return {result:{status:'ok',kind:'playlist',list:id,items}};
}
export default {
  async fetch(request,env,ctx){
    const url=new URL(request.url);
    if(url.pathname==='/health'&&request.method==='GET')
      return respond({status:'ok',service:'Jotify YT shared API',configured:Boolean(env.YOUTUBE_API_KEY)});
    const isSearch=url.pathname==='/api/yt/search';
    const isPlaylist=url.pathname==='/api/yt/playlist';
    if(!isSearch&&!isPlaylist)return respond({status:'failure',error:'Not found'},404);
    if(request.method!=='GET')return respond({status:'failure',error:'GET only'},405);
    if(url.search.length>450)return respond({status:'failure',error:'Query too long'},400);
    if(!env.YOUTUBE_API_KEY)
      return respond({status:'failure',error:'Jotify YT awaits owner setup.'},503);
    const canonical=new URL(url.origin+url.pathname);
    if(isSearch){
      canonical.searchParams.set('kind',url.searchParams.get('kind')||'song');
      canonical.searchParams.set('q',(url.searchParams.get('q')||'').trim().replace(/\s+/g,' ').toLowerCase());
    }else canonical.searchParams.set('list',url.searchParams.get('list')||'');
    const cache=caches.default;
    const key=new Request(canonical.toString(),{method:'GET'});
    const hit=await cache.match(key);
    if(hit)return hit;
    // Approximate per-location throttling: monitor Google quota separately.
    if(env.YT_RATE_LIMITER){
      const ip=request.headers.get('CF-Connecting-IP')||'unidentified';
      const {success}=await env.YT_RATE_LIMITER.limit({key:ip});
      if(!success)return respond({status:'failure',error:'Too many searches. Try in a minute.'},429);
    }
    const result=isSearch?await search(url,env):await playlist(url,env);
    if(result.error)return result.error;
    const response=respond(result.result,200,true);
    ctx.waitUntil(cache.put(key,response.clone()));
    return response;
  }
};
