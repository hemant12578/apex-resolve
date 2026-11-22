import {NextResponse} from 'next/server';
import {db, storageAdmin} from '@/lib/db';

const respond = (body: object, status = 200) =>
  NextResponse.json(body, {status, headers: {'Cache-Control': 'private, no-store'}});

export async function POST(req: Request) {
  try {
    const client = await db();
    const {data: {user}} = await client.auth.getUser();
    if (!user) return respond({error: 'Sign in to upload attachments.'}, 401);

    const body = await req.json();
    const fileName = String(body.fileName || 'attachment').trim();
    const fileType = String(body.fileType || 'application/octet-stream').trim();
    const fileBase64 = String(body.fileBase64 || '').trim();

    if (!fileBase64) return respond({error: 'Missing file content.'}, 400);

    const bytes = Buffer.from(fileBase64, 'base64');
    // Max 20MB for media
    if (bytes.length > 20971520) return respond({error: 'Attachment must be 20 MB or less.'}, 400);

    const id = crypto.randomUUID();
    const ext = fileName.includes('.') ? fileName.split('.').pop()! : 'bin';
    const storagePath = `chat/${user.id}/${id}.${ext}`;

    const bucket = storageAdmin().storage.from('evidence');
    const {error: uploadErr} = await bucket.upload(storagePath, bytes, {
      contentType: fileType,
      metadata: {uploader_id: user.id, original_name: fileName},
      upsert: true,
    });

    if (uploadErr) {
      return respond({error: `Upload failed: ${uploadErr.message}`}, 500);
    }

    // Try to get public or signed URL
    let fileUrl = '';
    const {data: signedData} = await bucket.createSignedUrl(storagePath, 60 * 60 * 24 * 7); // 7 days
    if (signedData?.signedUrl) {
      fileUrl = signedData.signedUrl;
    } else {
      const {data: publicData} = bucket.getPublicUrl(storagePath);
      fileUrl = publicData.publicUrl;
    }

    return respond({
      ok: true,
      url: fileUrl,
      storagePath,
      name: fileName,
      size: bytes.length,
      type: fileType,
    });
  } catch (e) {
    return respond({error: e instanceof Error ? e.message : 'Attachment upload failed.'}, 500);
  }
}
