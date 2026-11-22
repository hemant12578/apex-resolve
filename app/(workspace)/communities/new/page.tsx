import Link from 'next/link';
import {UsersRound} from 'lucide-react';
import {Button, Feedback, Form, type Query} from '@/components/WorkspaceUI';

export default async function NewCommunity({searchParams}:{searchParams:Promise<Query>}) {
  return <section className="community-create panel stack">
    <Link href="/communication">← Messages</Link>
    <UsersRound aria-hidden="true" size={36}/>
    <h1>Create community</h1>
    <p>Choose a name. You can invite people after your group chat opens.</p>
    <Feedback q={await searchParams}/>
    <Form op="community"><label>Community name<input name="title" required maxLength={100} autoFocus placeholder="e.g. Weekend crew"/></label>
      <Button>Create community</Button>
    </Form>
  </section>;
}
