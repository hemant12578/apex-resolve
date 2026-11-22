import {cache} from 'react';
import {session,rows} from './db';

export const contactList=cache(async function contactList(){
  const {client,user}=await session();
  const records=rows(await client.from('contact_requests').select('id,sender,recipient,status')
    .or('sender.eq.'+user.id+',recipient.eq.'+user.id).order('id'));
  return records.map(row=>({
    peer:row.sender===user.id?row.recipient:row.sender,
    status:row.status,
    incoming:row.recipient===user.id,
  }));
});
