import {NextResponse} from 'next/server';
import {db, rows, storageAdmin} from '@/lib/db';
import {validateEvidence} from '@/lib/file-validation.mjs';

const respond = (body: object, status = 200) =>
  NextResponse.json(body, {status, headers: {'Cache-Control': 'private, no-store'}});

export async function GET(req: Request) {
  try {
    const client = await db();
    const {data: {user}} = await client.auth.getUser();
    if (!user) return respond({error: 'Sign in to access issues.'}, 401);

    const url = new URL(req.url);
    const id = url.searchParams.get('id');

    // If no ID, return directory list of issues
    if (!id) {
      const issues = rows(
        await client
          .from('issues')
          .select('id,title,status,priority,updated_at,workspace_id')
          .order('updated_at', {ascending: false})
          .limit(100)
      );
      return respond({items: issues});
    }

    const {data: i, error: issueErr} = await client.from('issues').select('*').eq('id', id).maybeSingle();
    if (issueErr || !i) return respond({error: 'Issue not found.'}, 404);

    const [tasks, evidence, audit, m, memberList, reviews] = await Promise.all([
      client.from('tasks').select('*').eq('issue_id', id).order('created_at'),
      client.from('evidence').select('*').eq('issue_id', id).order('created_at', {ascending: false}),
      client.from('audit_events').select('*').eq('issue_id', id).order('created_at', {ascending: false}).limit(100),
      client.from('workspace_members').select('role').eq('workspace_id', i.workspace_id).eq('user_id', user.id).maybeSingle(),
      client.from('workspace_members').select('user_id,role,profiles!inner(display_name)').eq('workspace_id', i.workspace_id),
      client.from('resolution_verifications').select('*').eq('issue_id', id).order('created_at', {ascending: false})
    ]);

    if (!m.data) return respond({error: 'Room access required.'}, 403);

    const role = m.data.role;
    const team = role !== 'guest';
    const canVerify = ['admin', 'verifier'].includes(role);
    const editable = ['OPEN', 'IN_PROGRESS'].includes(i.status);

    const people = rows(memberList).map(p => ({
      userId: p.user_id,
      role: p.role,
      name: (Array.isArray(p.profiles) ? p.profiles[0] : p.profiles)?.display_name || p.user_id,
    }));

    const evidenceList = rows(evidence);
    const independent =
      canVerify &&
      Boolean(i.verification_request_id && i.verification_requested_by) &&
      user.id !== i.assignee_id &&
      user.id !== i.verification_requested_by &&
      evidenceList.some(e => e.uploader_id !== user.id);

    return respond({
      issue: i,
      tasks: rows(tasks),
      evidence: evidenceList,
      audit: rows(audit),
      reviews: rows(reviews),
      people,
      permissions: {
        role,
        team,
        canVerify,
        editable,
        independent,
        isRequestedByMe: i.verification_requested_by === user.id,
      },
      currentUserId: user.id,
    });
  } catch (e) {
    return respond({error: e instanceof Error ? e.message : 'Could not load issue.'}, 500);
  }
}

export async function POST(req: Request) {
  try {
    const client = await db();
    const {data: {user}} = await client.auth.getUser();
    if (!user) return respond({error: 'Sign in to perform this action.'}, 401);

    const body = await req.json();
    const op = String(body.op || '').trim();

    async function rpc(name: string, args: Record<string, unknown>) {
      const {data, error} = await client.rpc(name, args);
      if (error) {
        throw new Error(error.code === 'P0001' ? error.message : `Database error: ${error.message}`);
      }
      return data;
    }

    if (op === 'issue') {
      const workspaceId = String(body.workspaceId || body.workspace || '').trim();
      const title = String(body.title || '').trim().slice(0, 180);
      const desc = String(body.description || '').trim().slice(0, 8000);
      const priority = String(body.priority || 'MEDIUM').trim();
      const assigneeId = body.assigneeId || body.assignee || null;
      const affected = Array.isArray(body.affected) ? body.affected : [];
      const id = String(body.id || crypto.randomUUID());

      if (!workspaceId || !title) return respond({error: 'Workspace and title are required.'}, 400);

      const issueId = await rpc('file_issue', {
        p_party: body.party || 'unknown',
        p_people: affected,
        p_workspace_id: workspaceId,
        p_title: title,
        p_description: desc,
        p_priority: priority,
        p_assignee_id: assigneeId,
        p_id: id,
      });

      return respond({ok: true, issueId: issueId || id});
    }

    const issueId = String(body.issueId || body.issue || '').trim();
    if (!issueId) return respond({error: 'Issue ID is required.'}, 400);

    const {data: access, error: denied} = await client.rpc('can_access_issue', {p_issue_id: issueId});
    if (denied || !access) return respond({error: 'Room access required.'}, 403);

    if (op === 'transition') {
      const action = String(body.action || '').trim();
      const notes = String(body.notes || '').trim().slice(0, 4000);
      const tags = (Array.isArray(body.tags) ? body.tags : String(body.tags || '').split(','))
        .map((t: string) => t.trim())
        .filter(Boolean)
        .slice(0, 10);
      const reviewRequest = body.reviewRequest || null;

      await rpc('transition_issue', {
        p_request_id: reviewRequest,
        p_issue_id: issueId,
        p_action: action,
        p_notes: notes,
        p_tags: tags,
      });

      return respond({ok: true, action});
    }

    if (op === 'task') {
      const title = String(body.title || '').trim().slice(0, 180);
      const desc = String(body.description || '').trim().slice(0, 4000);
      const status = String(body.status || 'TODO').trim();
      const assigneeId = body.assigneeId || body.assignee || null;
      const taskId = body.id || null;

      if (!title) return respond({error: 'Task title is required.'}, 400);

      const savedId = await rpc('save_task', {
        p_issue_id: issueId,
        p_title: title,
        p_description: desc,
        p_status: status,
        p_assignee_id: assigneeId,
        p_id: taskId,
      });

      return respond({ok: true, taskId: savedId || taskId});
    }

    if (op === 'deleteTask') {
      const taskId = String(body.id || body.taskId || '').trim();
      if (!taskId) return respond({error: 'Task ID is required.'}, 400);

      await rpc('delete_task', {p_issue_id: issueId, p_id: taskId});
      return respond({ok: true, deleted: true});
    }

    if (op === 'evidence') {
      const kind = String(body.kind || 'note').trim();
      const desc = String(body.description || '').trim().slice(0, 4000);
      const id = String(body.id || crypto.randomUUID());
      let value: string | null = body.value ? String(body.value).trim() : null;

      if (kind === 'file') {
        const {data: open} = await client.from('issues').select('status').eq('id', issueId).single();
        if (!open || !['OPEN', 'IN_PROGRESS'].includes(open.status)) {
          return respond({error: 'Review or reopen the issue before uploading evidence.'}, 400);
        }

        if (body.fileBase64 && body.fileName) {
          const rawBytes = Buffer.from(body.fileBase64, 'base64');
          if (rawBytes.length > 4194304) return respond({error: 'Choose a file up to 4 MiB.'}, 400);

          const {ext, mime} = validateEvidence(body.fileName, body.fileType || 'application/octet-stream', new Uint8Array(rawBytes));
          value = `${issueId}/${id}.${ext}`;
          const bucket = storageAdmin().storage.from('evidence');
          const {error: uploadErr} = await bucket.upload(value, rawBytes, {
            contentType: mime,
            metadata: {uploader_id: user.id},
          });
          if (uploadErr) return respond({error: `Upload failed: ${uploadErr.message}`}, 500);
        }
      } else if (kind === 'url') {
        if (!value || !/^https:\/\//i.test(value)) return respond({error: 'Enter an HTTPS evidence URL.'}, 400);
      } else if (kind === 'note') {
        value = null;
        if (!desc) return respond({error: 'Write an evidence note.'}, 400);
      } else {
        return respond({error: 'Unknown evidence type.'}, 400);
      }

      await rpc('add_evidence', {
        p_issue_id: issueId,
        p_kind: kind,
        p_description: desc,
        p_value: value,
        p_id: id,
      });

      return respond({ok: true, evidenceId: id});
    }

    return respond({error: 'Unknown operation.'}, 400);
  } catch (e) {
    return respond({error: e instanceof Error ? e.message : 'Operation failed.'}, 500);
  }
}
