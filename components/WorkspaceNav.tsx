'use client';
import Link from 'next/link';
import {usePathname,useSearchParams} from 'next/navigation';
import {Compass, MessagesSquare, Users, Layers, Sparkles, ClipboardList, LibraryBig, Settings} from 'lucide-react';

const destinations=[
  {href:'/dashboard?view=explore',label:'Explorer',icon:Compass},
  {href:'/communication?tab=chats',label:'Direct messages',icon:MessagesSquare},
  {href:'/communication?tab=groups',label:'Groups',icon:Users},
  {href:'/dashboard?view=explore#workspaces',label:'Workspaces',icon:Layers},
  {href:'/communication?tab=ai',label:'Apex AI',icon:Sparkles},
  {href:'/dashboard?view=resolution',label:'Resolution',icon:ClipboardList},
  {href:'/knowledge',label:'Knowledge',icon:LibraryBig},
  {href:'/settings',label:'Settings',icon:Settings}
];
export default function WorkspaceNav(){
  const path=usePathname(),params=useSearchParams();
  return <nav className="workspace-nav" aria-label="Workspace navigation">{destinations.map(({href,label,icon:Icon})=>{
    const target=new URL(href,'https://apex.invalid');
    const selected=!target.hash&&path===target.pathname&&Array.from(target.searchParams).every(([key,value])=>(params.get(key)??(key==='tab'?(params.has('room')?'rooms':'chats'):null))===value);
    return <Link key={href} href={href} title={label} aria-label={label} aria-current={selected?'page':undefined}><Icon size={20} aria-hidden="true"/><span>{label}</span></Link>;
  })}</nav>;
}
