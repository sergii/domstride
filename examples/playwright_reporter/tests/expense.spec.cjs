const {test,expect} = require("@playwright/test");
const http = require("node:http");
let server, origin;
test.beforeAll(async()=>{
  server=http.createServer((req,res)=>{
    res.writeHead(200,{"Content-Type":"text/html"});
    res.end(req.url==="/expenses/new"?'<input aria-label="Amount"><button onclick="this.textContent=&quot;Saved&quot;">Save</button>':"<p>Actual</p>");
  });
  await new Promise(resolve=>server.listen(0,"127.0.0.1",resolve));
  origin="http://127.0.0.1:"+server.address().port;
});
test.afterAll(async()=>{if(server) await new Promise(resolve=>server.close(resolve));});

test("create expense", async ({page})=>{
  await test.step("Enter amount",async()=>{
    await page.goto(origin+"/expenses/new");
    await page.getByLabel("Amount").fill("25");
    await expect(page.getByLabel("Amount")).toHaveValue("25");
  });
  await test.step("Save expense",async()=>{
    await page.getByRole("button",{name:"Save"}).click();
    await expect(page.getByRole("button",{name:"Saved"})).toBeVisible();
  });
});

test("failed assertion", async ({page})=>{
  await page.goto(origin+"/expenses/1");
  await test.step("Verify result",async()=>{
    await expect(page.locator("p")).toHaveText("Expected",{timeout:200});
  });
});

test.skip("skipped case",()=>{ throw new Error("must not execute"); });

test.describe("retry behavior",()=>{
  test.describe.configure({retries:1});
  test("retry attempt",async({},info)=>{
    expect(info.retry).toBe(1);
  });
});
