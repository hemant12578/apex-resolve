import { randomUUID } from "node:crypto";
import { test, expect, type Page } from "@playwright/test";

async function signIn(page:Page,email:string,password:string){
  await page.goto("/login");
  await page.getByLabel("Email address").fill(email);
  await page.getByLabel("Password",{exact:true}).fill(password);
  await page.getByRole("button",{name:"Sign in",exact:true}).click();
  await page.waitForURL(/\/(welcome|dashboard)$/);
  if(new URL(page.url()).pathname==="/welcome")await page.getByRole("link",{name:"Skip and explore"}).click();
  await expect(page.getByRole("form",{name:"Home view"})).toBeVisible();
}
const room = (page:Page)=>page.getByRole("region",{name:"Room conversation"});
async function send(page:Page,text:string) {
  await room(page).getByLabel("Message",{exact:true}).fill(text);
  await room(page).getByRole("button",{name:"Send message"}).click();
}
async function received(page:Page,text:string) {
  await expect(room(page).getByRole("log").getByText(text,{exact:true})).toBeVisible({timeout:45000});
}


for (const withChat of [false, true]) {
const scenario=withChat ? "two accounts resolve and verify a new issue with real Nexconn delivery" : "two accounts resolve and verify a new issue using Supabase";
test(scenario,async({browser,baseURL})=>{
  test.skip((withChat ? process.env.E2E_LIVE : process.env.E2E_CORE)!=="1", "Requires a configured disposable project.");
  test.setTimeout(240000);
  const { E2E_ADMIN_EMAIL:adminEmail,E2E_ADMIN_PASSWORD:adminPass,E2E_MEMBER_EMAIL:memberEmail,E2E_MEMBER_PASSWORD:memberPass }=process.env;
  if (!adminEmail || !adminPass || !memberEmail || !memberPass || adminEmail===memberEmail)
    throw new Error("Set two distinct confirmed test accounts as documented in docs/BROWSER_TESTS.md.");
  const ca=await browser.newContext({baseURL}), cb=await browser.newContext({baseURL});
  try {
    const admin=await ca.newPage(),member=await cb.newPage();
    await Promise.all([signIn(admin,adminEmail,adminPass),signIn(member,memberEmail,memberPass)]);
    await member.reload();
    await expect(member.getByRole("form",{name:"Home view"})).toBeVisible();
    const marker=randomUUID().slice(0,8), workspace="Checkout incident "+marker, title="Checkout failure "+marker;
    await admin.locator("details#create summary").click();
    await admin.getByLabel("Workspace name").fill(workspace);
    await admin.getByRole("button",{name:"Create workspace",exact:true}).click();
    await expect(admin.getByRole("heading",{name:workspace,exact:true})).toBeVisible();
    const workspaceUrl=admin.url();
    await admin.getByText("Open an issue",{exact:true}).click();
    await admin.getByLabel("Issue title").fill(title);
    await admin.getByLabel("Problem description").fill("Checkout failed after the deployment.");
    await admin.getByRole("button",{name:"Create resolution room"}).click();
    await expect(admin.getByRole("heading",{name:title,exact:true})).toBeVisible();
    const issueUrl=admin.url(), issueId=new URL(issueUrl).pathname.split("/").pop();
    const denied=await cb.request.post("/api/chat/session",{headers:{Origin:new URL(baseURL!).origin},data:{issueId}});
    expect(denied.status()).toBe(404);
    await admin.goto(workspaceUrl);
    await admin.getByText("Invite a member",{exact:true}).click();
    await admin.getByLabel("Role",{exact:true}).selectOption("member");
    await admin.getByRole("button",{name:"Create invitation link"}).click();
    const invite=await admin.locator(".token-link code").innerText();
    await member.goto(new URL(invite).pathname);
    await member.getByRole("button",{name:"Accept invitation"}).click();
    await expect(member.getByRole("heading",{name:workspace,exact:true})).toBeVisible();
    await Promise.all([admin.goto(issueUrl),member.goto(issueUrl)]);
    if (withChat) {
    for (const page of [admin,member]) {
      await expect(room(page).locator(".chat-connection")).toHaveText("Connected",{timeout:45000});
    }
    const first="Checkout is failing "+marker, reply="Investigating "+marker;
    await send(admin,first); await received(member,first);
    await send(member,reply); await received(admin,reply);
    await member.reload(); await received(member,first); await received(member,reply);
    await cb.setOffline(true);
    await expect(room(member).locator(".chat-connection")).not.toHaveText("Connected",{timeout:45000});
    const missed="Retest completed "+marker;
    await send(admin,missed);
    await cb.setOffline(false);
    await expect(room(member).locator(".chat-connection")).toHaveText("Connected",{timeout:45000});
    await received(member,missed);
    }
    await member.getByRole("button",{name:"Start work"}).click();
    await member.getByRole("button",{name:"Request verification"}).click();
    await expect(member.getByRole("alert").filter({hasText:/evidence/i})).toBeVisible();
    await member.getByText("Add task",{exact:true}).click();
    const createTask=member.locator("#tasks details[open] form").first();
    const task="Run checkout regression "+marker;
    await createTask.getByLabel("Title",{exact:true}).fill(task);
    await createTask.getByRole("button",{name:"Create task"}).click();
    const taskPanel=member.locator("#tasks details").filter({has:member.locator("summary",{hasText:task})});
    await taskPanel.locator("summary").click();
    await taskPanel.getByLabel("Status",{exact:true}).selectOption("DONE");
    await taskPanel.getByRole("button",{name:"Save task"}).click();
    await expect(taskPanel.locator("summary")).toContainText(/done/i);
    await member.getByText("Add file",{exact:true}).click();
    const fileForm=member.locator("#evidence details").filter({has:member.locator("summary",{hasText:"Add file"})});
    await fileForm.getByLabel("Description",{exact:true}).fill("Passing checkout regression log");
    const proof="Confirmed checkout payment "+marker;
    await fileForm.locator("input[type=file]").setInputFiles({name:"checkout.log",mimeType:"text/plain",buffer:Buffer.from(proof)});
    await fileForm.getByRole("button",{name:"Attach evidence"}).click();
    const download=await member.getByRole("link",{name:"Download private file"}).getAttribute("href");
    expect(download).toBeTruthy();
    const fileResponse=await cb.request.get(download!);
    expect(fileResponse.status()).toBe(200);
    expect(await fileResponse.text()).toBe(proof);
    if(withChat) await received(admin,"evidence attached");
    await member.getByRole("button",{name:"Request verification"}).click();
    await expect(member.getByText(/Awaiting independent reviewer/)).toBeVisible();
    await expect(member.getByRole("button",{name:"Approve resolution"})).toHaveCount(0);
    await admin.reload();
    await admin.getByLabel("Review notes").fill("Verified the checkout regression.");
    await admin.getByLabel("Knowledge tags").fill("checkout");
    await admin.getByRole("button",{name:"Approve resolution"}).click();
    await expect(admin.locator(".status-verified_resolved")).toBeVisible();
    if(withChat) await received(member,"verification approved");
    await admin.goto("/knowledge?q="+encodeURIComponent(marker));
    await expect(admin.getByRole("link",{name:title})).toBeVisible();
    await admin.locator(".account summary").click();
    await admin.getByRole("button",{name:"Sign out"}).click();
    await admin.goto("/dashboard");
    await expect(admin).toHaveURL(/\/login(?:\?|$)/);
  } finally {
    await Promise.all([ca.close(),cb.close()]);
  }
});
}
