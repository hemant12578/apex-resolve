'use client';
import {useId,useRef,useState,type ReactNode} from 'react';
const labels=['Conversation','Details & tasks','Evidence & review'];
export default function RoomPanels({children}:{children:ReactNode}){
 const [selected,select]=useState(0),group=useId(),tabs=useRef<Array<HTMLButtonElement|null>>([]);
 return <div className="room-section" data-selected={selected}>
 <div className="mobile-tabs" role="tablist" aria-label="Resolution room panels">{labels.map((label,i)=><button key={i} id={group+'-tab-'+i} role="tab" aria-selected={selected===i} aria-controls={['conversation','details-panel','evidence-panel'][i]} tabIndex={i===selected?0:-1} ref={el=>{tabs.current[i]=el}} onClick={()=>select(i)} onKeyDown={e=>{
   const offset=e.key==='ArrowRight'?1:e.key==='ArrowLeft'?-1:0;
   if(offset){e.preventDefault();const next=(i+offset+labels.length)%labels.length;select(next);tabs.current[next]?.focus()}
 }}>{label}</button>)}</div>{children}</div>
}
