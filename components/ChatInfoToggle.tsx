'use client';

import {Info, X} from 'lucide-react';
import {createContext, useContext, useEffect, useState, type ReactNode} from 'react';

const Details = createContext({visible:false, setVisible: (_visible:boolean) => { void _visible; }});

export function ChatShell({thread, info, children}:{thread:boolean; info:string; children:ReactNode}) {
  const [choice,setChoice]=useState<boolean|null>(null);
  const [wide,setWide]=useState(false);
  useEffect(()=>{
    const media=window.matchMedia('(min-width:1280px)');
    const update=()=>setWide(media.matches);
    update();
    media.addEventListener('change',update);
    return ()=>media.removeEventListener('change',update);
  },[]);
  const visible=choice??wide;
  return <Details.Provider value={{visible,setVisible:setChoice}}>
    <div className="wa-shell" data-open={thread} data-has-info={info}
      data-info-open={choice===true || undefined} data-info-closed={choice===false || undefined}
      onKeyDown={event=>{if(event.key==='Escape' && visible) setChoice(false);}}>{children}</div>
  </Details.Provider>;
}

export default function ChatInfoToggle({hasInfo,close=false}:{hasInfo:boolean;close?:boolean}){
  const {visible,setVisible}=useContext(Details);
  if(!hasInfo)return null;
  return <button type="button" className="wa-icon-btn" onClick={()=>setVisible(close?false:!visible)}
    aria-controls="chat-info" aria-label={close?'Close chat details':visible?'Hide chat details':'Show chat details'}
    aria-expanded={visible}>{close?<X size={18}/>:<Info size={18}/>}</button>;
}
