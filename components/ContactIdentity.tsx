'use client';
import {useState} from 'react';
export default function ContactIdentity({handle,pin,setupPending}:{handle:string;pin:string|null;setupPending:boolean}){
  const [visible,show]=useState(false),[notice,notify]=useState('');
  async function copy(value:string,label:string){
    try{await navigator.clipboard.writeText(value);notify(label+' copied.')}catch{notify('Select the value and copy it manually.')}
  }
  return <section className="panel stack"><h2>Chat identity</h2><div><strong>{handle}</strong> <button className="btn" onClick={()=>copy(handle,'Username')}>Copy username</button></div>
    <p>Share your contact PIN to let someone open a private chat. Everyone else can send a request.</p>
    {pin?<div><code>{visible?pin:'•••• •••• ••••'}</code> <button className="btn" onClick={()=>show(!visible)}>{visible?'Hide':'Show'} PIN</button> <button className="btn" onClick={()=>copy(pin,'PIN')}>Copy PIN</button></div>:<p>{setupPending?'Contact PIN setup is pending on the workspace database.':'Could not load your PIN. Refresh Settings to retry.'}</p>}<small role="status">{notice}</small></section>;
}
