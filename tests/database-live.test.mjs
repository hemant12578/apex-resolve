import assert from 'node:assert/strict'
import { randomUUID } from 'node:crypto'
import { test } from 'node:test'
import { createClient } from '@supabase/supabase-js'

// Run against a disposable, loopback-only Supabase stack with the migrations installed.
test('local Supabase Auth, sessions, PostgREST and private Storage verification workflow', {
  skip: process.env.RUN_LOCAL_SUPABASE_TEST !== '1', timeout: 180000,
}, async () => {
  const url=process.env.NEXT_PUBLIC_SUPABASE_URL, publishable=process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY
  assert.ok(['127.0.0.1','localhost','[::1]'].includes(new URL(url).hostname),'Use an isolated loopback test stack')
  const service=createClient(url,process.env.SUPABASE_SECRET_KEY,{auth:{persistSession:false}})
  const storage=new Map()
  const persistence={getItem:key=>storage.get(key)??null,setItem:(key,v)=>storage.set(key,v),removeItem:key=>storage.delete(key)}
  const client=()=>createClient(url,publishable,{auth:{autoRefreshToken:false,persistSession:true,storage:persistence}})
  const checked=async pending=>{
    const {data,error}=await pending
    assert.ifError(error)
    return data
  }
  const email='qa-'+randomUUID()+'@example.test', password=randomUUID()+'A1!'
  const signed=client()
  const registered=await checked(signed.auth.signUp({email,password}))
  assert.ok(registered.user?.id)
  // Local projects with confirmation enabled can confirm this isolated test user via the Auth admin API.
  if(!registered.session) await checked(service.auth.admin.updateUserById(registered.user.id,{email_confirm:true}))
  await checked(signed.auth.signInWithPassword({email,password}))
  const restored=client()
  assert.equal((await checked(restored.auth.getUser())).user.id,registered.user.id)
  const workspace=await checked(restored.rpc('create_workspace',{p_name:'Disposable QA team',p_description:'Local API smoke test'}))
  const issue=await checked(restored.rpc('create_issue',{p_workspace_id:workspace,p_title:'Checkout validation',p_description:'Callback evidence',p_priority:'high'}))
  const transition=action=>restored.rpc('transition_issue',{p_issue_id:issue,p_action:action})
  await checked(transition('start'))
  assert.match((await transition('request')).error.message,/Attach evidence/)
  const id=randomUUID(), path=issue+'/'+id+'.txt'
  await checked(service.storage.from('evidence').upload(path,new TextEncoder().encode('Staging checkout passed'),{contentType:'text/plain',metadata:{uploader_id:registered.user.id}}))
  await checked(restored.rpc('add_evidence',{p_issue_id:issue,p_kind:'file',p_description:'Checkout replay',p_value:path,p_id:id}))
  const signedUrl=(await checked(restored.storage.from('evidence').createSignedUrl(path,60))).signedUrl
  const download=await fetch(signedUrl)
  assert.equal(download.status,200)
  assert.equal(await download.text(),'Staging checkout passed')
  await checked(transition('request'))
  const review=await checked(restored.from('issues').select('verification_request_id').eq('id',issue).single())
  const request={p_issue_id:issue,p_action:'approve',p_request_id:review.verification_request_id}
  assert.match((await restored.rpc('transition_issue',request)).error.message,/independent reviewer/)
  const reviewer=createClient(url,publishable,{auth:{persistSession:false}})
  const reviewerEmail='qa-review-'+randomUUID()+'@example.test'
  await checked(service.auth.admin.createUser({email:reviewerEmail,password,email_confirm:true}))
  await checked(reviewer.auth.signInWithPassword({email:reviewerEmail,password}))
  const invite=await checked(restored.rpc('create_invitation',{p_workspace_id:workspace,p_role:'verifier'}))
  await checked(reviewer.rpc('accept_invitation',{p_token:invite}))
  await checked(reviewer.rpc('transition_issue',request))
  const entry=await checked(restored.from('knowledge_entries').select('issue_id').textSearch('search_vector','checkout',{config:'simple'}).eq('issue_id',issue).single())
  assert.equal(entry.issue_id,issue)
  await checked(restored.auth.signOut({scope:'local'}))
  const publicClient=client()
  assert.equal((await publicClient.auth.getSession()).data.session,null)
  assert.ok((await publicClient.rpc('transition_issue',{p_issue_id:issue,p_action:'reopen'})).error)
})
