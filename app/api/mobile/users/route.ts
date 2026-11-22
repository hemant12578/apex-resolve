import {NextResponse} from 'next/server';
import {db, rows, storageAdmin} from '@/lib/db';
import {matchesMember, memberHandle} from '@/lib/handles';

const respond = (body: object, status = 200) =>
  NextResponse.json(body, {status, headers: {'Cache-Control': 'private, no-store'}});

export async function GET(req: Request) {
  try {
    const client = await db();
    const {data: {user}} = await client.auth.getUser();
    if (!user) return respond({error: 'Sign in to your workspace.'}, 401);

    const url = new URL(req.url);
    const term = (url.searchParams.get('q') || '').trim().slice(0, 100);
    const page = Math.max(1, parseInt(url.searchParams.get('page') || '1', 10) || 1);
    const pageSize = 30;
    const offset = (page - 1) * pageSize;

    const directory = storageAdmin();
    let members: {id: string; display_name: string}[] = [];

    if (!term || term === '@') {
      members = rows(
        await client
          .from('profiles')
          .select('id,display_name')
          .neq('id', user.id)
          .order('display_name')
          .range(offset, offset + pageSize - 1)
      );
    } else {
      for (let start = 0; members.length <= offset + pageSize; start += 250) {
        const batch = rows(
          await directory
            .from('profiles')
            .select('id,display_name')
            .neq('id', user.id)
            .order('id')
            .range(start, start + 249)
        );
        members.push(...batch.filter(p => matchesMember(p.id, p.display_name, term)));
        if (batch.length < 250) break;
      }
      members = members.slice(offset, offset + pageSize);
    }

    // Fetch contact statuses for current user
    const peerIds = members.map(m => m.id);
    const contacts = peerIds.length
      ? rows(
          await client
            .from('contact_requests')
            .select('id,sender,recipient,status')
            .or(`sender.eq.${user.id},recipient.eq.${user.id}`)
        )
      : [];

    const contactMap = new Map<string, {id: string; status: string; incoming: boolean}>();
    for (const c of contacts) {
      const peer = c.sender === user.id ? c.recipient : c.sender;
      contactMap.set(peer, {
        id: c.id,
        status: c.status,
        incoming: c.recipient === user.id,
      });
    }

    const items = members.map(m => {
      const rel = contactMap.get(m.id);
      return {
        id: m.id,
        displayName: m.display_name,
        handle: memberHandle(m.id, m.display_name),
        contactStatus: rel ? rel.status : 'none',
        incoming: rel ? rel.incoming : false,
        contactRequestId: rel ? rel.id : null,
      };
    });

    return respond({items, page, hasMore: members.length === pageSize});
  } catch (e) {
    return respond({error: e instanceof Error ? e.message : 'Directory search failed.'}, 500);
  }
}
