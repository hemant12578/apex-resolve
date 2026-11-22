'use client';
import {useEffect} from 'react';
import {useRouter} from 'next/navigation';

export default function ContactSync({snapshot}:{snapshot:string}){
  const router=useRouter();
  useEffect(()=>{
    const controller=new AbortController();
    let busy=false;
    async function check(){
      if(document.hidden||busy)return;
      busy=true;
      try{
        const result=await fetch('/api/chat/contacts',{signal:controller.signal,cache:'no-store'});
        if(result.ok&&JSON.stringify(await result.json())!==snapshot&&!controller.signal.aborted)router.refresh();
      }catch{/* Retry when the tab is visible again. */}finally{busy=false}
    }
    const timer=setInterval(check,5000);
    document.addEventListener('visibilitychange',check);
    window.addEventListener('focus',check);
    return ()=>{controller.abort();clearInterval(timer);document.removeEventListener('visibilitychange',check);window.removeEventListener('focus',check)};
  },[router,snapshot]);
  return null;
}
