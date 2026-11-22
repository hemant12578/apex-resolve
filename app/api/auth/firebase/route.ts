import {NextRequest,NextResponse} from 'next/server';
import {createClient} from '@supabase/supabase-js';
import {db} from '@/lib/db';
import {verifiedFirebaseEmail} from '@/lib/firebase-token';

const MAX_NAME=100;

function cleanName(value:unknown){
  if(typeof value!=='string')return '';
  return value.normalize('NFKC').replace(/\s+/g,' ').trim().slice(0,MAX_NAME);
}

export async function POST(req:NextRequest){
  try{
    const origin=req.headers.get('origin');
    if(!origin||new URL(origin).host!==req.headers.get('host'))return NextResponse.json({error:'Invalid request origin.'},{status:403});
    const body=await req.json() as {idToken?:string;displayName?:string};
    const {email,uid}=await verifiedFirebaseEmail(String(body.idToken??''));
    const displayName=cleanName(body.displayName);
    const admin=createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!,process.env.SUPABASE_SECRET_KEY!,{auth:{persistSession:false,autoRefreshToken:false}});
    const {data,error}=await admin.auth.admin.generateLink({type:'magiclink',email,options:{data:{firebase_uid:uid,...(displayName?{display_name:displayName}:{})}}});
    if(error||!data.properties?.hashed_token||!data.user)throw new Error('Could not prepare your data session.');
    // Google sign-ups and returning accounts already exist, so the trigger may not run.
    // Persisting the chosen username here keeps the profile correct on every path.
    if(displayName){
      const {error:profileError}=await admin.from('profiles').upsert({id:data.user.id,display_name:displayName},{onConflict:'id'});
      if(profileError)throw new Error('Could not save your username.');
    }
    const {error:sessionError}=await (await db()).auth.verifyOtp({token_hash:data.properties.hashed_token,type:'magiclink'});
    if(sessionError)throw new Error(sessionError.message || 'Could not start your data session.');
    const homeMode=data.user.user_metadata?.home_mode;
    return NextResponse.json({
      ok:true,
      firstLogin:!data.user.last_sign_in_at,
      destination:homeMode==='communication'?'/communication':homeMode==='resolution'?'/dashboard?view=resolution':'/dashboard'
    });
  }catch(error){return NextResponse.json({error:error instanceof Error?error.message:'Sign-in failed.'},{status:401});}
}
