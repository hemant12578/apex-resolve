import {db} from '@/lib/db';
import {NextResponse} from 'next/server';
export async function GET(_:Request,{params}:{params:Promise<{id:string}>}){
 const {id}=await params;const client=await db();
 const {data:{user}}=await client.auth.getUser();
 if(!user)return new Response('Sign in required',{status:401});
 const {data}=await client.from('evidence').select('kind,value').eq('id',id).maybeSingle();
 if(!data||data.kind!=='file')return new Response('Evidence unavailable',{status:404});
 const {data:link}=await client.storage.from('evidence').createSignedUrl(data.value,60,{download:true});
 if(!link)return new Response('File unavailable',{status:404});
 return NextResponse.redirect(link.signedUrl,{headers:{'Cache-Control':'private, no-store','Referrer-Policy':'no-referrer'}});
}
