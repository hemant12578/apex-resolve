import {NextResponse} from 'next/server';
import {db, rows, storageAdmin} from '@/lib/db';
import {memberHandle} from '@/lib/handles';

const respond = (body: object, status = 200) =>
  NextResponse.json(body, {status, headers: {'Cache-Control': 'private, no-store'}});

export async function GET() {
  try {
    const client = await db();
    const {data: {user}} = await client.auth.getUser();
    if (!user) return respond({error: 'Sign in to access your profile.'}, 401);

    const {data: profile} = await storageAdmin().from('profiles').select('*').eq('id', user.id).maybeSingle();
    const memberships = rows(
      await client
        .from('workspace_members')
        .select('role,workspaces(id,name,description,community_state)')
        .eq('user_id', user.id)
    );

    const displayName = profile?.display_name || user.user_metadata?.display_name || 'Member';
    const handle = memberHandle(user.id, displayName);

    return respond({
      user: {
        id: user.id,
        email: user.email,
        displayName,
        handle,
        bio: profile?.bio || '',
        avatarUrl: profile?.avatar_url || null,
        memberships: memberships.map(m => {
          const w = Array.isArray(m.workspaces) ? m.workspaces[0] : m.workspaces;
          return {
            role: m.role,
            workspaceId: w?.id,
            name: w?.name,
            isCommunity: Boolean(w?.community_state),
          };
        }),
      },
    });
  } catch (e) {
    return respond({error: e instanceof Error ? e.message : 'Could not load profile.'}, 500);
  }
}

export async function POST(req: Request) {
  try {
    const client = await db();
    const {data: {user}} = await client.auth.getUser();
    if (!user) return respond({error: 'Sign in to update your profile.'}, 401);

    const body = await req.json();
    const displayName = String(body.displayName || body.display_name || '').trim().slice(0, 100);
    const bio = String(body.bio || '').trim().slice(0, 500);
    let avatarUrl = body.avatarUrl || null;

    // Handle avatar photo upload if provided as base64
    if (body.avatarBase64) {
      try {
        const rawBytes = Buffer.from(body.avatarBase64, 'base64');
        const filename = `${user.id}/avatar_${Date.now()}.jpg`;
        const bucket = storageAdmin().storage.from('avatars');
        const {error: uploadErr} = await bucket.upload(filename, rawBytes, {
          contentType: 'image/jpeg',
          upsert: true,
        });
        if (!uploadErr) {
          const {data: publicData} = bucket.getPublicUrl(filename);
          avatarUrl = publicData.publicUrl;
        }
      } catch {
        // Fallback if avatar bucket is restricted: save data URI or profile metadata
        if (body.avatarBase64.length < 50000) {
          avatarUrl = `data:image/jpeg;base64,${body.avatarBase64}`;
        }
      }
    }

    if (displayName) {
      await client.rpc('update_profile', {p_display_name: displayName});
      await client.auth.updateUser({data: {display_name: displayName}});
      await storageAdmin().from('profiles').upsert(
        {
          id: user.id,
          display_name: displayName,
          ...(bio !== undefined ? {bio} : {}),
          ...(avatarUrl ? {avatar_url: avatarUrl} : {}),
        },
        {onConflict: 'id'}
      );
    }

    return respond({
      ok: true,
      displayName: displayName || user.user_metadata?.display_name,
      avatarUrl,
      bio,
    });
  } catch (e) {
    return respond({error: e instanceof Error ? e.message : 'Could not update profile.'}, 500);
  }
}
