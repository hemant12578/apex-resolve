'use client';
import {useState} from 'react';
import {CheckCheck,Copy,Reply,ShieldCheck} from 'lucide-react';
import type {ReactNode} from 'react';

const clock=new Intl.DateTimeFormat(undefined,{hour:'numeric',minute:'2-digit'});

export default function ChatBubble({id,own,sender,text,time,quote,event,detail,onReply,children}:{
  id?:string;own:boolean;sender?:string;text:string;time:Date;quote?:string;event?:boolean;
  detail?:string;onReply?:()=>void;children?:ReactNode
}){
  const [copyStatus,setCopyStatus]=useState('');
  return <article id={id} data-own={own} className={event?'chat-event':'chat-message'}>
    {sender&&<strong className="bubble-author">{event&&<ShieldCheck size={14}/>} {sender}</strong>}
    {quote&&<blockquote>{quote}</blockquote>}
    <p>{text}</p>
    {detail&&<p>{detail}</p>}
    <footer className="bubble-tools"><time dateTime={time.toISOString()}>{clock.format(time)}</time>
      {own&&<span className="bubble-ticks" aria-label="Sent"><CheckCheck size={14}/></span>}
      <button type="button" title="Copy message" aria-label="Copy message" onClick={async()=>{try{await navigator.clipboard.writeText(text);setCopyStatus('Copied');}catch{setCopyStatus('Copy unavailable');}}}><Copy size={15}/></button>
      {copyStatus&&<small role="status">{copyStatus}</small>}
      {onReply&&<button type="button" title="Reply" aria-label="Reply" onClick={onReply}><Reply size={15}/></button>}
    </footer>{children}
  </article>;
}
