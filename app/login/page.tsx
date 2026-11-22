import {redirect} from 'next/navigation';
import AuthPage, { type AuthSearchParams } from "@/components/AuthPage";
import {configured,db} from '@/lib/db';
import {homeMode} from '@/lib/modes';

export const metadata = {title: "Sign in"};

export default async function Login({searchParams}: {searchParams: AuthSearchParams}) {
  if(configured()){
    try{
      const {data:{user}}=await (await db()).auth.getUser();
      if(user){
        const mode=homeMode(user.user_metadata?.home_mode);
        redirect(mode==='communication'?'/communication':mode==='resolution'?'/dashboard?view=resolution':'/dashboard');
      }
    }catch{}
  }
  return <AuthPage mode="login" searchParams={searchParams}/>;
}
