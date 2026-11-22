import Link from 'next/link';
import {contactList} from '@/lib/contact-list';
import {storageAdmin,rows} from '@/lib/db';
import {memberHandle} from '@/lib/handles';
import ContactSync from './ContactSync';

export default async function ConversationSidebar(){
  const contacts=await contactList();
  const visible=contacts.filter(c=>c.status==='accepted'||(c.incoming&&c.status==='pending'));
  const profiles=visible.length?rows(await storageAdmin().from('profiles').select('id,display_name').in('id',visible.map(c=>c.peer))):[];
  const names=new Map(profiles.map(person=>[person.id,person.display_name]));
  return <details open className="workspace-links"><summary>Direct messages</summary><ContactSync snapshot={JSON.stringify(contacts)}/>
    {visible.map(contact=>{
      const name=names.get(contact.peer)||'Team member';
      return <Link className="contact-shortcut" key={contact.peer} href={'/communication?tab='+(contact.status==='accepted'?'chats':'people')+'&peer='+contact.peer}><strong>{name}</strong><small>{memberHandle(contact.peer,name)}{contact.status==='pending'?' · Request':''}</small></Link>;
    })}
    <Link href="/communication?tab=people">Find people</Link>
  </details>;
}
