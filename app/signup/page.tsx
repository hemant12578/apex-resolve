import {redirect} from 'next/navigation';
import AuthPage, { type AuthSearchParams } from "@/components/AuthPage";
import {configured,db} from '@/lib/db';
import {homeMode} from '@/lib/modes';

export const metadata = {title: "Create an account"};

export default async function Signup({searchParams}: {searchParams: AuthSearchParams}) {
  if(configured()){
    try{
      const {data:{user}}=await (await db()).auth.getUser();
      if(user){
        const mode=homeMode(user.user_metadata?.home_mode);
        redirect(mode==='communication'?'/communication':mode==='resolution'?'/dashboard?view=resolution':'/dashboard');
      }
    }catch{}
  }
  return <AuthPage mode="signup" searchParams={searchParams}/>;
}
