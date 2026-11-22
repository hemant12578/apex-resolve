import {Form,Button,type Query,Feedback} from '@/components/WorkspaceUI';
import {db,configured} from '@/lib/db';
import Link from 'next/link';
export default async function Invitation({params,searchParams}:{params:Promise<{token:string}>,searchParams:Promise<Query>}){
 const {token}=await params,client=configured()?await db():null,user=client?(await client.auth.getUser()).data.user:null;
 return <main className="page"><section className="panel stack"><h1>Workspace invitation</h1><Feedback q={await searchParams}/>{user?<Form op="accept" fields={{token}}><p>Accept this invitation as {user.email}.</p><Button>Accept invitation</Button></Form>:<><p>Sign in, then reopen your invitation link to accept.</p><Link className="btn" href="/login">Sign in</Link></>}</section></main>
}
