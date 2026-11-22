import {NextResponse} from 'next/server';
import {db} from '@/lib/db';

const respond = (body: object, status = 200) =>
  NextResponse.json(body, {status, headers: {'Cache-Control': 'private, no-store'}});

export async function POST(req: Request) {
  try {
    const client = await db();
    const {data: {user}} = await client.auth.getUser();
    if (!user) return respond({error: 'Sign in to manage contacts.'}, 401);

    const body = await req.json() as {peer?: string; operation?: string; pin?: string};
    const peer = String(body.peer || '').trim();
    const operation = String(body.operation || '').trim();
    const pin = String(body.pin || '').trim();

    if (!peer || !operation) return respond({error: 'Missing peer or operation.'}, 400);

    const {data, error} = await client.rpc('contact_action', {
      peer,
      operation,
      supplied_pin: pin,
    });

    if (error) {
      return respond({error: error.message || 'Operation failed.'}, 400);
    }

    if (data === 'invalid') {
      return respond({ok: false, invalidPin: true, error: 'That PIN did not match.'}, 200);
    }

    return respond({ok: true, result: data});
  } catch (e) {
    return respond({error: e instanceof Error ? e.message : 'Contact operation failed.'}, 500);
  }
}
