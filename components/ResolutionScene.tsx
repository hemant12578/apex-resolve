'use client';
import Image from 'next/image';
import {useState} from 'react';
import {MessagesSquare, Paperclip, ShieldCheck} from 'lucide-react';

const stages=[
  {label:'Report',icon:MessagesSquare,title:'“I paid, but my cart is still full.”',detail:'A customer reports a checkout problem. Support and engineering open one room to investigate.'},
  {label:'Evidence',icon:Paperclip,title:'The retry created a second order.',detail:'An engineer attaches the failing receipt and a passing retry test for the proposed fix.'},
  {label:'Review',icon:ShieldCheck,title:'One payment. One order.',detail:'A reviewer checks the receipt against the test and records the verified resolution.'},
];
export default function ResolutionScene(){
  const [selected,select]=useState(0);
  const stage=stages[selected];
  return <section className="resolution-scene" aria-label="Interactive checkout example">
    <Image src="/resolve-terrain.webp" alt="" width={1200} height={870} priority className="scene-map"/>
    <div className="scene-stack" key={selected}>
      <div className="scene-layer far" aria-hidden="true"/><div className="scene-layer near" aria-hidden="true"/>
      <article className="scene-layer front" aria-live="polite">
        <small>EXAMPLE ROOM / CHECKOUT</small><stage.icon size={32} aria-hidden="true"/>
        <h2>{stage.title}</h2><p>{stage.detail}</p>
      </article>
    </div>
    <div className="scene-controls" aria-label="Example stages">{stages.map(({label},i)=><button key={label} aria-pressed={selected===i} onClick={()=>select(i)}>{label}</button>)}</div>
  </section>;
}
