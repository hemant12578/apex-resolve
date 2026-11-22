import {NextRequest,NextResponse} from 'next/server';
import {db} from '@/lib/db';
export async function GET(req:NextRequest){
 const code=req.nextUrl.searchParams.get('code');
 if(code){const {error}=await (await db()).auth.exchangeCodeForSession(code);
 if(!error)return NextResponse.redirect(new URL(req.nextUrl.searchParams.get('flow')==='reset'?'/reset?change=1':'/dashboard',req.url));}
 return NextResponse.redirect(new URL('/login?error=Link+expired+or+invalid.+Open+the+link+in+the+original+browser.',req.url));
}
