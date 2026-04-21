import { Command } from "commander";
import { getConfig } from "../config.js";
import { makeRequest } from "../http.js";
import { printResult, parseJSON } from "../output.js";

export function makeWorkspacesCommand(): Command {
  const cmd = new Command("workspaces").description("Manage workspaces and members");

  // ── Workspace CRUD ─────────────────────────────────────────────────────────
  cmd
    .command("list")
    .description("List all workspaces")
    .action(async (_opts, sub) => {
      try {
        const { apiKey, baseURL } = getConfig(sub);
        const result = await makeRequest(apiKey, baseURL, "GET", "/workspaces");
        printResult(result, sub.optsWithGlobals());
      } catch (err) {
        console.error("Error:", err instanceof Error ? err.message : String(err));
        process.exit(1);
      }
    });

  cmd
    .command("create")
    .description("Create a workspace")
    .requiredOption("--name <name>", "Workspace name")
    .requiredOption("--slug <slug>", "Workspace slug (URL-safe)")
    .action(async (opts, sub) => {
      try {
        const { apiKey, baseURL } = getConfig(sub);
        const result = await makeRequest(apiKey, baseURL, "POST", "/workspaces", {
          name: opts.name,
          slug: opts.slug,
        });
        printResult(result, sub.optsWithGlobals());
      } catch (err) {
        console.error("Error:", err instanceof Error ? err.message : String(err));
        process.exit(1);
      }
    });

  cmd
    .command("get")
    .description("Get a workspace by ID")
    .argument("<id>", "Workspace ID")
    .action(async (id, _opts, sub) => {
      try {
        const { apiKey, baseURL } = getConfig(sub);
        const result = await makeRequest(apiKey, baseURL, "GET", `/workspaces/${id}`);
        printResult(result, sub.optsWithGlobals());
      } catch (err) {
        console.error("Error:", err instanceof Error ? err.message : String(err));
        process.exit(1);
      }
    });

  cmd
    .command("update")
    .description("Update a workspace")
    .argument("<id>", "Workspace ID")
    .requiredOption("--data <json>", "Updated fields as JSON")
    .action(async (id, opts, sub) => {
      try {
        const { apiKey, baseURL } = getConfig(sub);
        const result = await makeRequest(apiKey, baseURL, "PATCH", `/workspaces/${id}`, parseJSON(opts.data, "data"));
        printResult(result, sub.optsWithGlobals());
      } catch (err) {
        console.error("Error:", err instanceof Error ? err.message : String(err));
        process.exit(1);
      }
    });

  cmd
    .command("delete")
    .description("Delete a workspace")
    .argument("<id>", "Workspace ID")
    .action(async (id, _opts, sub) => {
      try {
        const { apiKey, baseURL } = getConfig(sub);
        const result = await makeRequest(apiKey, baseURL, "DELETE", `/workspaces/${id}`);
        printResult(result, sub.optsWithGlobals());
      } catch (err) {
        console.error("Error:", err instanceof Error ? err.message : String(err));
        process.exit(1);
      }
    });

  // ── Members ────────────────────────────────────────────────────────────────
  const members = new Command("members").description("Manage workspace members");

  members
    .command("list")
    .description("List members of a workspace")
    .argument("<workspace-id>", "Workspace ID")
    .action(async (workspaceId, _opts, sub) => {
      try {
        const { apiKey, baseURL } = getConfig(sub);
        const result = await makeRequest(apiKey, baseURL, "GET", `/workspaces/${workspaceId}/members`);
        printResult(result, sub.optsWithGlobals());
      } catch (err) {
        console.error("Error:", err instanceof Error ? err.message : String(err));
        process.exit(1);
      }
    });

  members
    .command("invite")
    .description("Invite a member to a workspace")
    .argument("<workspace-id>", "Workspace ID")
    .requiredOption("--email <email>", "Invitee email address")
    .option("--role <role>", "Role: member or admin", "member")
    .action(async (workspaceId, opts, sub) => {
      try {
        const { apiKey, baseURL } = getConfig(sub);
        const result = await makeRequest(apiKey, baseURL, "POST", `/workspaces/${workspaceId}/members`, {
          email: opts.email,
          role: opts.role,
        });
        printResult(result, sub.optsWithGlobals());
      } catch (err) {
        console.error("Error:", err instanceof Error ? err.message : String(err));
        process.exit(1);
      }
    });

  members
    .command("update")
    .description("Update a member's role")
    .argument("<workspace-id>", "Workspace ID")
    .argument("<user-id>", "User ID")
    .requiredOption("--role <role>", "New role: member or admin")
    .action(async (workspaceId, userId, opts, sub) => {
      try {
        const { apiKey, baseURL } = getConfig(sub);
        const result = await makeRequest(
          apiKey,
          baseURL,
          "PATCH",
          `/workspaces/${workspaceId}/members/${userId}`,
          { role: opts.role }
        );
        printResult(result, sub.optsWithGlobals());
      } catch (err) {
        console.error("Error:", err instanceof Error ? err.message : String(err));
        process.exit(1);
      }
    });

  members
    .command("remove")
    .description("Remove a member from a workspace")
    .argument("<workspace-id>", "Workspace ID")
    .argument("<user-id>", "User ID")
    .action(async (workspaceId, userId, _opts, sub) => {
      try {
        const { apiKey, baseURL } = getConfig(sub);
        const result = await makeRequest(
          apiKey,
          baseURL,
          "DELETE",
          `/workspaces/${workspaceId}/members/${userId}`
        );
        printResult(result, sub.optsWithGlobals());
      } catch (err) {
        console.error("Error:", err instanceof Error ? err.message : String(err));
        process.exit(1);
      }
    });

  cmd.addCommand(members);

  return cmd;
}
