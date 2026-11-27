const {test,expect} = require("@playwright/test");

test("create expense", async ({page})=>{
  await test.step("Enter amount",async()=>{
    await page.setContent('<input aria-label="Amount"><button onclick="this.textContent=\'Saved\'">Save</button>');
    await page.getByLabel("Amount").fill("25");
    await expect(page.getByLabel("Amount")).toHaveValue("25");
  });
  await test.step("Save expense",async()=>{
    await page.getByRole("button",{name:"Save"}).click();
    await expect(page.getByRole("button",{name:"Saved"})).toBeVisible();
  });
});

test("failed assertion", async ({page})=>{
  await page.setContent("<p>Actual</p>");
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
