import {createServerClient} from '@supabase/ssr';
import {NextResponse,type NextRequest} from 'next/server';
export async function proxy(req:NextRequest){
  let res=NextResponse.next({request:req});
  if(!process.env.NEXT_PUBLIC_SUPABASE_URL||!process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY)return res;
  const client=createServerClient(process.env.NEXT_PUBLIC_SUPABASE_URL,process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY,{cookies:{
    getAll:()=>req.cookies.getAll(),setAll(items){
      for(const {name,value} of items)req.cookies.set(name,value);
      res=NextResponse.next({request:req});
      for(const {name,value,options} of items)res.cookies.set(name,value,options);
    }
  }});
  await client.auth.getUser();
  return res;
}
export const config={matcher:['/dashboard/:path*','/issues/:path*','/settings','/knowledge','/workspaces/:path*','/invite/:path*','/api/:path*','/reset']};
