import 'server-only';
import {cache} from 'react';
import {createServerClient} from '@supabase/ssr';
import {createClient} from '@supabase/supabase-js';
import {cookies} from 'next/headers';
import {redirect} from 'next/navigation';

export function configured(){
  return Boolean(process.env.NEXT_PUBLIC_SUPABASE_URL && process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY);
}
export const db=cache(async function db(){
  if(!configured()) throw new Error('Configure the Supabase URL and publishable key in .env.local.');
  const jar=await cookies();
  return createServerClient(process.env.NEXT_PUBLIC_SUPABASE_URL!,process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!,{cookies:{
    getAll:()=>jar.getAll(),
    setAll(items){try{for(const {name,value,options} of items) jar.set(name,value,options)}catch{/* Server component reads use the proxy for refresh. */}}
  }});
});
export function storageAdmin(){
  if(!process.env.SUPABASE_SECRET_KEY)throw new Error('File storage requires SUPABASE_SECRET_KEY.');
  return createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!,process.env.SUPABASE_SECRET_KEY,{auth:{persistSession:false,autoRefreshToken:false}});
}
export const session=cache(async function session(){
  if(!configured())redirect('/login?notice=Configure+Supabase+in+.env.local+to+sign+in.');
  const client=await db();
  const {data:{user}}=await client.auth.getUser();
  if(!user)redirect('/login');
  return {client,user};
});
export function rows<T>(result:{data:T[]|null,error:unknown}):T[]{
  if(result.error)throw new Error('Could not load records. Check the connection and database migration.');
  return result.data??[];
}
