'use client';
import {useEffect,useRef,useState} from 'react';
import {Sparkles,Send} from 'lucide-react';
import {askApex} from '@/lib/copilot';

type Turn={role:'user'|'assistant';content:string};
export default function ApexAssistant(){
  const [history,setHistory]=useState<Turn[]>([]),[pending,setPending]=useState('');
  const [draft,setDraft]=useState(''),[error,setError]=useState('');
  const log=useRef<HTMLDivElement>(null);
  useEffect(()=>{if(log.current)log.current.scrollTop=log.current.scrollHeight},[history,pending]);
  async function send(){
    const message=draft.trim();
    if(pending||!message)return;
    const next:Turn[]=[...history,{role:'user',content:message}];
    setPending(message);setDraft('');setError('');
    try{
      const result=await askApex(next.slice(-12));
      if('error' in result){setError(result.error);setDraft(message);return}
      setHistory([...next,{role:'assistant',content:result.answer}]);
    }catch{setError('Connection interrupted. Try again.');setDraft(message)}finally{setPending('')}
  }
  return <div className="assistant-thread chat-pane">
    <header><span className="ai-avatar"><Sparkles/></span><div><h2>Apex AI</h2><small>AI assistant · OpenRouter free model</small></div></header>
    <div ref={log} role="log" aria-live="polite" className="bubble-stream">
      <article><strong>Apex AI</strong><p>Hi! What are you working on today?</p></article>
      {history.map((t,i)=><article data-role={t.role} key={i}><strong>{t.role==='user'?'You':'Apex AI'}</strong><p>{t.content}</p></article>)}
      {pending&&<><article data-role="user"><strong>You</strong><p>{pending}</p></article><small>Apex AI is typing…</small></>}
    </div>
    {error&&<p role="alert">{error}</p>}
    <form className="chat-compose" onSubmit={e=>{e.preventDefault();void send()}}>
      <input aria-label="Message Apex AI" placeholder="Message Apex AI…" maxLength={4000} value={draft} onChange={e=>setDraft(e.target.value)} disabled={Boolean(pending)} required/>
      <button disabled={Boolean(pending)||!draft.trim()} aria-label="Send message"><Send size={18}/></button>
    </form></div>
}
