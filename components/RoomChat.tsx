'use client';

import { Fragment, useEffect, useRef, useState } from 'react';
import type { Message } from '@nexconn/chat';
import { CheckCheck, MessageCircle, Send, Search, X } from 'lucide-react';
import { z } from 'zod';
import ChatBubble from './ChatBubble';
import MessageIssue from './MessageIssue';
import {useRoomTranscript} from './RoomTranscript';

const sessionSchema=z.object({
  peerName:z.string().optional(),token:z.string(),userId:z.string(),channelId:z.string(),appKey:z.string(),region:z.enum(['SG','NA','SA'])
});
const workflowSchema=z.object({eventId:z.uuid(),action:z.string().max(100),detail:z.string().max(400).optional()});
const dayFormat=new Intl.DateTimeFormat(undefined,{weekday:'short',day:'numeric',month:'short',year:'numeric'});
type Entry={mine?:boolean;source?:Message;quote?:string;id:string; sender:string; text:string; time:number; detail?:string; event:boolean};
type RoomControls={send:(text:string,parent?:Message)=>Promise<void>; older:()=>Promise<void>};
let initialized=false;
// Serialize connect/disconnect for the SDK singleton across rapid route changes.
let lifecycle=Promise.resolve();
function schedule(operation:()=>Promise<void>) {
  const result=lifecycle.then(operation);
  lifecycle=result.catch(()=>{});
  return result;
}
export default function RoomChat({issueId,workspace,destinations,sourcePath,direct=false,community=false,memberNames}:{memberNames?:Record<string,string>;issueId:string;workspace?:string;destinations?:{id:string;name:string}[];sourcePath?:string;direct?:boolean;community?:boolean}) {
  const [retry,setRetry]=useState(0);
  return <ChatConnection key={issueId+retry} memberNames={memberNames} community={community} direct={direct} workspace={workspace} destinations={destinations} sourcePath={sourcePath} issueId={issueId} retry={()=>setRetry(r=>r+1)}/>;
}
function ChatConnection({issueId,retry,workspace,destinations,sourcePath,direct,community,memberNames}:{memberNames?:Record<string,string>;community:boolean;direct:boolean;issueId:string;workspace?:string;destinations?:{id:string;name:string}[];sourcePath?:string;retry:()=>void}) {
  const {setMessages:setTranscript}=useRoomTranscript();
  const [status,setStatus]=useState('Connecting'), [error,setError]=useState('');
  const [messages,setMessages]=useState<Entry[]>([]), [more,setMore]=useState(false);
  const [searchOpen,setSearchOpen]=useState(false);
  const [search,setSearch]=useState('');
  const [reply,setReply]=useState<Entry|null>(null);
  const [draft,setDraft]=useState(''),[busy,setBusy]=useState(false),[loadingHistory,setLoadingHistory]=useState(false);
  const [receipts,setReceipts]=useState<Record<string,number>>({});
  const [failedSend,setFailedSend]=useState(false);
  const followedHash=useRef('');
  const historyAnchor=useRef<{id:string;top:number}|null>(null);
  const composer=useRef<HTMLTextAreaElement>(null);
  const controls=useRef<RoomControls|null>(null), list=useRef<HTMLDivElement>(null), sticky=useRef(true);
  useEffect(()=>{
    const hash=window.location.hash;
    if(hash.startsWith('#message-') && followedHash.current!==hash){
      const target=document.getElementById(hash.slice(1))||Array.from(list.current?.querySelectorAll('article[id]')||[]).find(el=>'#message-'+encodeURIComponent(el.id.slice(8))===hash);
      if(target){followedHash.current=hash;sticky.current=false;target.scrollIntoView({block:'center'});return;}
    }
    if(historyAnchor.current && list.current){
      const item=document.getElementById(historyAnchor.current.id);
      if(item) list.current.scrollTop+=item.getBoundingClientRect().top-historyAnchor.current.top;
      historyAnchor.current=null;
    }else if(sticky.current && list.current) list.current.scrollTop=list.current.scrollHeight;
  },[messages]);
  useEffect(()=>{
    setTranscript(messages.filter(message=>!message.event).slice(-50).map(({id,text,time})=>({id,text,time})));
  },[messages,setTranscript]);
  useEffect(()=>{
    const abort=new AbortController();
    let active=true, disconnect:(()=>Promise<void>)|undefined;
    let pump:ReturnType<typeof setInterval>|undefined;
    async function connect() {
      const response=await fetch('/api/chat/session',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(community?{communityId:issueId}:direct?{peerId:issueId}:{issueId}),signal:abort.signal});
      const payload=await response.json();
      if(!response.ok) throw Error(typeof payload.error==='string'?payload.error:'Could not connect.');
      const session=sessionSchema.parse(payload);
      const sdk=await import('@nexconn/chat');
      if(!active) return;
      if(!initialized){
        sdk.NCEngine.initialize({appKey:session.appKey,areaCode:sdk.AreaCode[session.region]});
        sdk.NCEngine.registerCustomMessages([{messageType:'Apex:Workflow',isPersisted:true,isCounted:true}]);
        initialized=true;
      }
      const channel=new sdk.GroupChannel(session.channelId), handler=crypto.randomUUID();
      const newQuery=()=>sdk.BaseChannel.createMessagesQuery({channelIdentifier:channel.identifier,startTime:Date.now(),pageSize:50,isAscending:false});
      let query=newQuery(),connected=false,ready=false;
      function ingest(batch:Message[]) {
        if(!active) return;
        const next:Entry[]=[],read:string[]=[];
        for(const message of batch){
          if(!channel.identifier.isEqualTo(message.channelIdentifier)) continue;
          const mine=message.senderUserId===session.userId;
          if((message.messageType===sdk.MessageType.TEXT || message.messageType===sdk.MessageType.REFERENCE) && typeof message.content.text==='string'){
            const quote=message.messageType===sdk.MessageType.REFERENCE ? z.object({text:z.string()}).safeParse(message.content.referMsg) : null;
            next.push({source:message,quote:quote ? (quote.success?quote.data.text.slice(0,180):'Earlier message') : undefined,id:message.messageId,mine,sender:mine?'You':session.peerName??memberNames?.[message.senderUserId]??('Member '+message.senderUserId.slice(1,9)),text:message.content.text,time:message.sentTime,event:false});
            if(!mine && message.needReceipt && !message.sentReceipt && document.visibilityState==='visible') read.push(message.messageId);
          }else if(message.messageType==='Apex:Workflow' && message.senderUserId==='ApexResolveWorkflow'){
            const event=workflowSchema.safeParse(message.content);
            if(event.success) next.push({id:event.data.eventId,sender:'Apex Resolve',text:event.data.action.replaceAll('_',' '),detail:event.data.detail,time:message.sentTime,event:true});
          }
        }
        if(next.length) setMessages(current=>{
          const merged=new Map(current.map(m=>[m.id,m]));
          for(const m of next) if(!merged.has(m.id)) merged.set(m.id,m);
          return [...merged.values()].sort((a,b)=>a.time-b.time || a.id.localeCompare(b.id));
        });
        if(read.length && channel instanceof sdk.GroupChannel) void channel.sendReadReceiptResponse(read).catch(()=>{});
      }
      async function load() {
        const current=query;
        const result=await current.loadNextPage();
        if(!active || current!==query) return;
        if(result.code!==0 || !result.data) throw Error('History could not load. Reconnect to try again.');
        ingest(result.data.data); setMore(current.hasNext);
      }
      sdk.NCEngine.addMessageHandler(handler,new sdk.MessageHandler({
        onMessageReceived:({messages})=>ingest(messages),
        onMessageReceiptResponse:({responses})=>{
          if(active) setReceipts(current=>({...current,...Object.fromEntries(responses.filter(r=>channel.identifier.isEqualTo(r.channelIdentifier)).map(r=>[r.messageId,r.readCount]))}));
        }
      }));
      sdk.NCEngine.addConnectionStatusHandler(handler,new sdk.ConnectionStatusHandler({
        onConnectionStatusChanged:({status,code})=>{
          if(!active) return;
          connected=status===sdk.ConnectionStatus.CONNECTED;
          if(connected){
            setStatus('Connected');
            if(ready){ query=newQuery(); void load().catch(()=>setError('Could not refresh history.')); }
          }else if(code===31010){
            setStatus('Disconnected');setError('Another session connected with this account.');
          }else setStatus(ready?'Reconnecting':'Connecting');
        }
      }));
      disconnect=async()=>{
        sdk.NCEngine.removeMessageHandler(handler);
        sdk.NCEngine.removeConnectionStatusHandler(handler);
        await sdk.NCEngine.disconnect();
      };
      const result=await sdk.NCEngine.connect({token:session.token});
      if(!active) return;
      if(result.code!==0 || result.data?.userId!==session.userId) throw Error('Nexconn could not authenticate this session. Check the App Key and region.');
      ready=true; connected=true;setStatus('Connected');
      controls.current={older:load,send:async (text,parent)=>{
        if(!connected) throw Error('Wait for the room to reconnect.');
        const params=parent ? new sdk.SendReferenceMessageParams(sdk.Helper.wrapAsReferenceMessageContent(parent,text)) : new sdk.SendTextMessageParams({text});
        params.needReceipt=!direct;
        const sent=params instanceof sdk.SendReferenceMessageParams ? await channel.sendMessage(params) : await channel.sendMessage(params);
        if(sent.code!==0 || !sent.data) throw Error('Message delivery failed. Try sending again.');
        sticky.current=true;ingest([sent.data]);
      }};
      let pumping=false;
      const drain=async()=>{
        if(pumping || !active) return;
        pumping=true;
        try {
          const r=await fetch('/api/chat/events',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({issueId}),signal:abort.signal});
          if(!r.ok && active) setError('Workflow updates are delayed. See the activity timeline for recorded changes.');
        } catch { /* A later interval retries committed outbox events. */ } finally {pumping=false;}
      };
      if(!direct&&!community){void drain();pump=setInterval(()=>void drain(),15000);}
      await load().catch(()=>setError('History could not load. Reconnect to try again.'));
    }
    void schedule(connect).catch(e=>{if(active){setStatus('Disconnected');setError(e instanceof Error?e.message:'Connection unavailable.');}});
    return ()=>{
      active=false;abort.abort();controls.current=null;
      if(pump)clearInterval(pump);
      void schedule(async()=>{await disconnect?.();});
    };
  },[issueId,direct,community,memberNames]);
  const term=search.trim().toLocaleLowerCase();
  const visible=term?messages.filter(message=>message.text.toLocaleLowerCase().includes(term)):messages;
  return <section aria-label="Room conversation"  className="panel room-chat">
    <div className="chat-heading"><h2 className={direct||community?"chat-kind":"room-title"}><MessageCircle size={20}/> {community?'Group chat':direct?'Private chat':'Conversation'}</h2><button type="button" className="chat-search-toggle" aria-expanded={searchOpen} onClick={()=>{setSearchOpen(!searchOpen);setSearch('')}} aria-label="Search messages" title="Search messages"><Search size={18}/></button><small className="chat-connection" data-connected={status==='Connected'} role="status">{status}</small></div>
    {error && <div role="alert" className="chat-alert">{error} <button type="button" onClick={retry}>Reconnect</button></div>}
    {searchOpen&&<div className="history-tools"><input type="search" aria-label="Search loaded messages" placeholder="Search loaded messages…" value={search} onChange={event=>setSearch(event.target.value)}/>{term&&<small role="status">{visible.length} matches</small>}</div>}
    <div ref={list} className="chat-history" role="log" aria-live="polite" onScroll={e=>{const box=e.currentTarget;sticky.current=box.scrollHeight-box.scrollTop-box.clientHeight<64;}}>
      {more && <button disabled={loadingHistory} type="button" onClick={async()=>{sticky.current=false;
        const first=list.current?.querySelector('article[id]');
        if(first)historyAnchor.current={id:first.id,top:first.getBoundingClientRect().top};
        setLoadingHistory(true);try{await controls.current?.older();}catch{historyAnchor.current=null;setError('Earlier messages could not load.');}finally{setLoadingHistory(false);}}}>Earlier messages</button>}
      {!messages.length && <p className="chat-empty">{status==='Connected'?(direct?'Send your first private message.':community?'Send the first message to your community.':'Start the conversation about this issue.'):status==='Disconnected'?'Conversation unavailable.':'Opening your private room…'}</p>}
      {term&&!visible.length&&<p className="chat-empty">No loaded messages match your search.</p>}
      {visible.map((m,i)=>{
        const previous=visible[i-1],time=new Date(m.time);
        const newDay=!previous || time.toDateString()!==new Date(previous.time).toDateString();
        const newAuthor=newDay || previous?.source?.senderUserId!==m.source?.senderUserId || previous?.event || m.time-previous.time>300000;
        return <Fragment key={m.id}>{newDay&&<div className="day-divider"><span>{dayFormat.format(time)}</span></div>}
          <ChatBubble id={'message-'+m.id} own={Boolean(m.mine)} sender={m.event || (!direct&&!m.mine&&newAuthor)?m.sender:undefined}
            time={time} text={m.text} quote={m.quote} event={m.event} detail={m.detail}
            onReply={m.source&&!busy?()=>{setReply(m);composer.current?.focus()}:undefined}>
            {(workspace||Boolean(destinations?.length))&&!m.event&&<MessageIssue sourcePath={sourcePath} destinations={destinations} workspace={workspace} issue={issueId} message={m.id} text={m.text}/>}
            {receipts[m.id]>0&&<small><CheckCheck size={13}/> Read by {receipts[m.id]}</small>}
          </ChatBubble></Fragment>;
      })}
    </div>
    {reply&&<aside className="reply-preview" aria-live="polite"><strong>Replying to {reply.sender}</strong><p>{reply.text.slice(0,180)}</p><button type="button" disabled={busy} onClick={()=>setReply(null)} aria-label="Cancel reply"><X size={16}/></button></aside>}
    <form className="chat-compose" onSubmit={async e=>{e.preventDefault();const text=draft.trim();if(!text || busy || status!=='Connected' || !controls.current)return;setError('');setFailedSend(false);setBusy(true);try{await controls.current.send(text,reply?.source);setReply(null);setDraft('');}catch{setFailedSend(true);}finally{setBusy(false);}}}>
      <textarea ref={composer} rows={1} onKeyDown={e=>{
        if(e.key==='Enter'&&!e.shiftKey&&!e.nativeEvent.isComposing){
          e.preventDefault();e.currentTarget.form?.requestSubmit();
        }
      }} aria-label="Message" maxLength={2000} value={draft} onChange={e=>{setDraft(e.target.value);setFailedSend(false);}} placeholder={direct?"Write a private message…" :community?"Message the community…":"Message the room…"} disabled={status!=='Connected'||busy}/>
      <span className="compose-hint" role="status">{busy?'Sending…':failedSend?'Send unconfirmed. Check the timeline before retrying.':'Enter to send · Shift+Enter for a new line'}</span>
      <button type="submit" disabled={busy || !draft.trim() || status!=='Connected'} aria-label="Send message"><Send size={18}/> <span>{failedSend?'Retry':'Send'}</span></button>
    </form>
  </section>;
}
