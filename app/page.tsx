import {redirect} from 'next/navigation';
import {configured,db} from '@/lib/db';
import {homeMode} from '@/lib/modes';

export const dynamic='force-dynamic';

// The product opens at the door, not at a marketing page.
// Signed-out people get the login screen; signed-in people land in their chosen view.
export default async function Home(){
  let user:null|{user_metadata?:Record<string,unknown>}=null;
  if(configured()){
    try{user=(await (await db()).auth.getUser()).data.user}catch{user=null}
  }
  if(user){
    const mode=homeMode(user.user_metadata?.home_mode);
    redirect(mode==='communication'?'/communication':mode==='resolution'?'/dashboard?view=resolution':'/dashboard');
  }
  redirect('/login');
}
