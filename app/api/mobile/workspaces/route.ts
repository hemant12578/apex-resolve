import {NextResponse} from 'next/server';
import {db, rows, storageAdmin} from '@/lib/db';
import {dismissCommunity} from '@/lib/nexconn';

const respond = (body: object, status = 200) =>
  NextResponse.json(body, {status, headers: {'Cache-Control': 'private, no-store'}});

export async function GET(req: Request) {
  try {
    const client = await db();
    const {data: {user}} = await client.auth.getUser();
    if (!user) return respond({error: 'Sign in to access workspaces.'}, 401);

    const url = new URL(req.url);
    const id = url.searchParams.get('id');

    if (id) {
      const {data: workspace, error: wErr} = await client.from('workspaces').select('*').eq('id', id).maybeSingle();
      if (wErr || !workspace) return respond({error: 'Workspace not found.'}, 404);

      const members = rows(
        await client
          .from('workspace_members')
          .select('user_id,role,profiles!inner(display_name)')
          .eq('workspace_id', id)
      ).map(m => ({
        userId: m.user_id,
        role: m.role,
        name: (Array.isArray(m.profiles) ? m.profiles[0] : m.profiles)?.display_name || m.user_id,
      }));

      const myMembership = members.find(m => m.userId === user.id);

      return respond({
        workspace,
        members,
        myRole: myMembership?.role || 'guest',
        isOwner: workspace.owner_id === user.id,
      });
    }

    // List all user's workspaces and communities
    const memberships = rows(
      await client
        .from('workspace_members')
        .select('role,workspaces(id,name,description,community_state,owner_id)')
        .eq('user_id', user.id)
    );

    const items = memberships.map(m => {
      const w = Array.isArray(m.workspaces) ? m.workspaces[0] : m.workspaces;
      return {
        id: w?.id,
        name: w?.name,
        description: w?.description,
        role: m.role,
        isCommunity: Boolean(w?.community_state),
        communityState: w?.community_state,
        isOwner: w?.owner_id === user.id,
      };
    });

    return respond({items});
  } catch (e) {
    return respond({error: e instanceof Error ? e.message : 'Could not load workspaces.'}, 500);
  }
}

export async function POST(req: Request) {
  try {
    const client = await db();
    const {data: {user}} = await client.auth.getUser();
    if (!user) return respond({error: 'Sign in to perform workspace actions.'}, 401);

    const body = await req.json();
    const op = String(body.op || '').trim();

    async function rpc(name: string, args: Record<string, unknown>) {
      const {data, error} = await client.rpc(name, args);
      if (error) {
        throw new Error(error.code === 'P0001' ? error.message : `Database error: ${error.message}`);
      }
      return data;
    }

    if (op === 'create' || op === 'community') {
      const name = String(body.name || '').trim().slice(0, 100);
      const desc = String(body.description || '').trim().slice(0, 4000);
      if (!name) return respond({error: 'Workspace name is required.'}, 400);

      const id = await rpc('create_workspace', {p_name: name, p_description: desc});
      return respond({ok: true, id});
    }

    if (op === 'update') {
      const wid = String(body.workspaceId || body.id || '').trim();
      const name = String(body.name || '').trim().slice(0, 100);
      const desc = String(body.description || '').trim().slice(0, 4000);
      if (!wid || !name) return respond({error: 'Workspace ID and name are required.'}, 400);

      await rpc('update_workspace', {p_workspace_id: wid, p_name: name, p_description: desc});
      return respond({ok: true, id: wid});
    }

    if (op === 'deleteCommunity') {
      const id = String(body.workspaceId || body.id || '').trim();
      const workspaces = storageAdmin().from('workspaces');
      const owner = await workspaces.select('community_state').eq('id', id).eq('owner_id', user.id).maybeSingle();
      if (owner.error || !owner.data) return respond({error: 'Only the community owner can delete this group.'}, 403);

      if (owner.data.community_state !== 'deleted') {
        await workspaces.update({community_state: 'closing'}).eq('id', id).eq('owner_id', user.id);
        await dismissCommunity(id);
        await workspaces.update({community_state: 'deleted'}).eq('id', id).eq('owner_id', user.id).eq('community_state', 'closing');
      }
      return respond({ok: true, deleted: true});
    }

    return respond({error: 'Unknown operation.'}, 400);
  } catch (e) {
    return respond({error: e instanceof Error ? e.message : 'Workspace operation failed.'}, 500);
  }
}
