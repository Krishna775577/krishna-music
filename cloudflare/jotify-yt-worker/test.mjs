import test from 'node:test';
import assert from 'node:assert/strict';
import worker from './src/index.js';

const base = 'https://jotify-example.workers.dev';
const objects = new Map();
globalThis.caches = {default:{
  async match(key){return objects.get(key.url)?.clone()||undefined;},
  async put(key,value){objects.set(key.url,value.clone());}
}};
const env = {YOUTUBE_API_KEY:'MOCK_KEY_ONLY',YT_RATE_LIMITER:{
  async limit(){return {success:true};}
}};
const context = {waitUntil(promise){void promise;}};
const originalFetch = globalThis.fetch;

test('GET health returns configured status without key',async()=>{
  const res=await worker.fetch(new Request(base+'/health'),env,context);
  assert.equal(res.status,200);
  const body=await res.json();
  assert.equal(body.configured,true);
  assert.equal(JSON.stringify(body).includes('MOCK_KEY_ONLY'),false);
});
test('Key not configured fails safe',async()=>{
  const res=await worker.fetch(new Request(base+'/api/yt/search?kind=song&q=Radhe'),{},context);
  assert.equal(res.status,503);
});
test('Bad kind is rejected',async()=>{
  const res=await worker.fetch(new Request(base+'/api/yt/search?kind=no&q=Hello'),env,context);
  assert.equal(res.status,400);
});
test('Video search is normalized, embeddable and cached',async()=>{
  let count=0;
  globalThis.fetch=async(url)=>{
    count++;
    assert.equal(url.searchParams.get('type'),'video');
    assert.equal(url.searchParams.get('videoEmbeddable'),'true');
    return Response.json({items:[{
      id:{videoId:'ABCdef0123_'},
      snippet:{title:'Test song',channelTitle:'Artist',
        thumbnails:{medium:{url:'https://i.ytimg.com/vi/ABCdef0123_/mqdefault.jpg'}}}
    },{id:{videoId:'bad'},snippet:{title:'No'}}]});
  };
  const request=new Request(base+'/api/yt/search?kind=song&q=Radhe');
  const res=await worker.fetch(request,env,context);
  assert.equal(res.status,200);
  assert.equal((await res.json()).items.length,1);
  assert.equal((await worker.fetch(request,env,context)).status,200);
  assert.equal(count,1);
});
test('Playlist video items use official endpoint',async()=>{
  globalThis.fetch=async(url)=>{
    assert.ok(url.href.includes('/youtube/v3/playlistItems?'));
    return Response.json({items:[{snippet:{
      resourceId:{videoId:'ABCdef0123_'},title:'Song one',videoOwnerChannelTitle:'Artist'
    }}]});
  };
  const res=await worker.fetch(new Request(base+'/api/yt/playlist?list=PL123456789'),env,context);
  assert.equal(res.status,200);
  assert.equal((await res.json()).items[0].channel,'Artist');
});
test('Google quota errors never leak upstream message',async()=>{
  globalThis.fetch=async()=>Response.json({
    error:{errors:[{reason:'quotaExceeded'}],message:'sensitive-google-text'}
  },{status:403});
  const res=await worker.fetch(new Request(base+'/api/yt/search?kind=playlist&q=Another'),env,context);
  assert.equal(res.status,429);
  assert.equal((await res.text()).includes('sensitive-google-text'),false);
});
test('Rate limit denies noncached query',async()=>{
  const limited={...env,YT_RATE_LIMITER:{async limit(){return {success:false}}}};
  const res=await worker.fetch(new Request(base+'/api/yt/search?kind=song&q=Unique'),limited,context);
  assert.equal(res.status,429);
});
process.on('exit',()=>{globalThis.fetch=originalFetch;});
