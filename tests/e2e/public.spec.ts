import { test, expect } from "@playwright/test";

test("landing preview switches from conversation to evidence and verification", async ({page})=>{
  await page.goto("/");
  await expect(page.getByRole("heading",{level:1})).toContainText(/verified/i);
  const options=page.locator("#communication");
  await expect(options.getByRole("link",{name:/Private messages/})).toHaveAttribute("href","/communication?tab=chats");
  await expect(options.getByRole("link",{name:/Community chats/})).toHaveAttribute("href","/communities/new");
  await page.getByRole("link",{name:"Explore workflow"}).click();
  await page.locator("#workflow").getByRole("button",{name:"Evidence",exact:true}).click();
  await expect(page.getByRole("heading",{name:"Review the regression test"})).toBeVisible();
  await page.getByRole("button",{name:"Verification",exact:true}).click();
  await expect(page.getByRole("heading",{name:"Confirm the checkout is working"})).toBeVisible();
});
test("the mobile landing and account forms fit the viewport",async({page})=>{
  await page.setViewportSize({width:375,height:812});
  await page.goto("/");
  await expect(page.getByRole("link",{name:"Create an account"})).toBeVisible();
  expect(await page.evaluate(()=>document.documentElement.scrollWidth)).toBeLessThanOrEqual(375);
  await page.getByRole("link",{name:"Create an account"}).click();
  await expect(page.getByLabel("Email address")).toBeVisible();
  await expect(page.getByLabel("Password",{exact:true})).toHaveAttribute("autocomplete","new-password");
  await page.getByRole("link",{name:"Sign in",exact:true}).click();
  await expect(page.getByLabel("Password",{exact:true})).toHaveAttribute("autocomplete","current-password");
  await page.getByRole("link",{name:"Forgot password?"}).click();
  await expect(page.getByRole("button",{name:"Send reset link"})).toBeVisible();
});
test("public requests cannot open protected pages or obtain a chat token",async({page,request,baseURL})=>{
  for (const path of ["/dashboard","/knowledge","/settings"]) {
    await page.goto(path);
    await expect(page).toHaveURL(/\/login(?:\?|$)/);
  }
  const response = await request.post("/api/chat/session",{
    headers:{Origin:new URL(baseURL!).origin},
    data:{issueId:"2b77c577-b9f9-4ab6-8519-7330990bc44d"}
  });
  expect([401,403,503]).toContain(response.status());
  expect(await response.json()).not.toHaveProperty("token");
});
