// Keep the old identifier searchable for handles that people already shared.
export function legacyHandle(id:string) {
  return '@'+BigInt('0x'+id.replaceAll('-','')).toString(36);
}

export function memberHandle(id:string,displayName:string) {
  const name=displayName.normalize('NFKC').toLowerCase().trim()
    .replace(/[^\p{L}\p{N}\p{M}]+/gu,'.').replace(/^\.|\.$/g,'') || 'member';
  return '@'+name+'.'+id.slice(0,8);
}

export function matchesMember(id:string,name:string,term:string) {
  const needle=term.normalize('NFKC').trim().toLowerCase().replace(/^@/,'');
  return [memberHandle(id,name),legacyHandle(id),name.normalize('NFKC').toLowerCase()]
    .some(value=>value.includes(needle));
}
