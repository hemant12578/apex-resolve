'use client';
import {useState} from 'react';
export default function InviteLink({token}:{token:string}){
  const [result,setResult]=useState('');
  const path='/invite/'+encodeURIComponent(token);
  return <div className="stack"><a className="token-link" href={path}>Invitation link</a><button className="btn" onClick={async()=>{
    try{await navigator.clipboard.writeText(new URL(path,location.origin).href);setResult('Link copied.');}
    catch{setResult('Use the invitation link above to copy its address.');}
  }}>Copy invitation link</button><small role="status">{result}</small></div>;
}
