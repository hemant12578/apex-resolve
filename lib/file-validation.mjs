export function validateEvidence(name, mime, bytes) {
  const ext = name.toLowerCase().split('.').pop();
  const types = {png:'image/png', jpg:'image/jpeg', jpeg:'image/jpeg', pdf:'application/pdf', txt:'text/plain', log:'text/plain'};
  if (!Object.hasOwn(types,ext) || (mime || (ext === 'log' ? 'text/plain' : '')) !== types[ext])
    throw new Error('Choose a PNG, JPEG, PDF or plain text log with a matching file type.');
  if (!bytes.length || bytes.length > 4*1024*1024) throw new Error('Choose a nonempty file of at most 4 MiB.');
  const magic = {png:[137,80,78,71,13,10,26,10],jpg:[255,216,255],jpeg:[255,216,255],pdf:[37,80,68,70,45]}[ext];
  if (magic && !magic.every((value,i)=>bytes[i]===value)) throw new Error('The file contents do not match the extension.');
  if (!magic) {
    if (bytes.includes(0)) throw new Error('The log contains binary data.');
    new TextDecoder('utf-8',{fatal:true}).decode(bytes);
  }
  return {ext, mime:types[ext]};
}
