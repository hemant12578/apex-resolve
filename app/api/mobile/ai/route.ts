import {NextResponse} from 'next/server';
import {askApex} from '@/lib/copilot';
import {db} from '@/lib/db';

export async function POST(req: Request) {
  try {
    const client = await db();
    const {data: {user}} = await client.auth.getUser();
    if (!user) return NextResponse.json({error: 'Sign in to use Apex AI.'}, {status: 401});
    const body = await req.json();
    const messages = Array.isArray(body) ? body : body.messages;
    const result = await askApex(messages);
    return NextResponse.json(result, {
      headers: {'Cache-Control': 'private, no-store'}
    });
  } catch (e) {
    return NextResponse.json({error: e instanceof Error ? e.message : 'Apex AI unavailable.'}, {status: 500});
  }
}
