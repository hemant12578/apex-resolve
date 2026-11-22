import {contactList} from '@/lib/contact-list';
export async function GET(){
  return Response.json(await contactList(),{headers:{'Cache-Control':'private, no-store'}});
}
