import Link from 'next/link';
import ModePicker from '@/components/ModePicker';
import {session} from '@/lib/db';

export default async function Welcome() {
  const {user}=await session();
  return <section className="panel stack">
    <h1>Where would you like to start?</h1>
    <p>You can change your home view at any time.</p>
    <ModePicker descriptions current={user.user_metadata.home_mode}/>
    <Link href="/dashboard">Skip and explore</Link>
  </section>;
}
