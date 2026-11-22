import {NextRequest,NextResponse} from 'next/server';
import {createClient} from '@supabase/supabase-js';
import {db} from '@/lib/db';
import {verifiedFirebaseEmail} from '@/lib/firebase-token';

export async function POST(req:NextRequest){
  try{
    const origin=req.headers.get('origin');
    if(!origin||new URL(origin).host!==req.headers.get('host'))return NextResponse.json({error:'Invalid request origin.'},{status:403});
    const body=await req.json() as {idToken?:string};
    const {email,uid}=await verifiedFirebaseEmail(String(body.idToken??''));
    const admin=createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!,process.env.SUPABASE_SECRET_KEY!,{auth:{persistSession:false,autoRefreshToken:false}});
    const {data,error}=await admin.auth.admin.generateLink({type:'magiclink',email,options:{data:{firebase_uid:uid}}});
    if(error||!data.properties?.hashed_token)throw new Error('Could not prepare your data session.');
    const {error:sessionError}=await (await db()).auth.verifyOtp({token_hash:data.properties.hashed_token,type:'magiclink'});
    if(sessionError)throw new Error('Could not start your data session.');
    return NextResponse.json({ok:true,firstLogin:!data.user.last_sign_in_at});
  }catch(error){return NextResponse.json({error:error instanceof Error?error.message:'Sign-in failed.'},{status:401});}
}
