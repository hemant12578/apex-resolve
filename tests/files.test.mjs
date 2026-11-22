import {test} from 'node:test';
import assert from 'node:assert/strict';
import {validateEvidence} from '../lib/file-validation.mjs';
test('Text logs accepted; binary, spoofed, oversized and empty evidence rejected',()=>{
 const text=new TextEncoder().encode('Payment callback verified');
 assert.equal(validateEvidence('test.log','',text).mime,'text/plain');
 for(const args of [['a.pdf','application/pdf',text],['a.exe','application/octet-stream',text],['a.txt','text/plain',new Uint8Array([0])],['a.txt','text/plain',new Uint8Array(0)],['a.txt','text/plain',new Uint8Array(4194305)]])assert.throws(()=>validateEvidence(...args));
});
