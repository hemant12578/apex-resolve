'use client';
import Link from 'next/link';
import {ChevronDown,LogOut,Settings,ShieldCheck,UserRound} from 'lucide-react';
import {logout} from '@/lib/actions';

export default function AccountMenu({email,name,handle}:{email:string;name:string;handle:string}){
  const initial=(name||email||'A').trim().slice(0,1).toUpperCase();
  return <details className="account account-v2">
    <summary aria-label="Account menu">
      <span className="account-avatar" aria-hidden="true">{initial}</span>
      <span className="account-copy"><strong>{name}</strong><small>{handle}</small></span>
      <ChevronDown size={15} className="account-chevron"/>
    </summary>
    <div className="account-pop">
      <header><span className="account-avatar large" aria-hidden="true">{initial}</span><div><strong>{name}</strong><small>{email}</small></div></header>
      <Link href="/settings"><Settings size={16}/> Settings</Link>
      <Link href="/settings"><UserRound size={16}/> Username and profile</Link>
      <Link href="/knowledge"><ShieldCheck size={16}/> Verified knowledge</Link>
      <form action={logout}><button className="account-signout"><LogOut size={16}/> Sign out</button></form>
    </div>
  </details>;
}
