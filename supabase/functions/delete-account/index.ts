// NutriSafe - permanently delete the caller's account, files and data.
// The secret (service) key is used ONLY here on the server, and only after the caller's own
// JWT has been verified. Database rows are removed by ON DELETE CASCADE from auth.users.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";

const BUCKETS = ["medical-reports", "avatars"];
const MAX_FOLDER_DEPTH = 5;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

/** Reads a key from the new JSON key dictionaries, falling back to the legacy variable. */
function projectKey(dictionaryVar: string, legacyVar: string): string {
  const raw = Deno.env.get(dictionaryVar);
  if (raw) {
    try {
      const keys = JSON.parse(raw) as Record<string, string>;
      const key = keys.default ?? Object.values(keys)[0];
      if (typeof key === "string" && key) return key;
    } catch {
      // fall through to the legacy key
    }
  }
  return Deno.env.get(legacyVar) ?? "";
}

/** Every file path under `prefix` (sub-folders are walked, with a depth limit). */
async function listFiles(
  admin: SupabaseClient,
  bucket: string,
  prefix: string,
  depth = 0,
): Promise<string[]> {
  if (depth > MAX_FOLDER_DEPTH) return [];
  const paths: string[] = [];
  for (let offset = 0; ; offset += 100) {
    const { data, error } = await admin.storage.from(bucket).list(prefix, { limit: 100, offset });
    if (error) throw error;
    if (!data || data.length === 0) break;
    for (const entry of data) {
      const path = `${prefix}/${entry.name}`;
      if (entry.id === null) {
        paths.push(...(await listFiles(admin, bucket, path, depth + 1))); // a folder
      } else {
        paths.push(path);
      }
    }
    if (data.length < 100) break;
  }
  return paths;
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  // 1. Verify who is calling.
  const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "").trim();
  if (!token) return json({ error: "Not signed in" }, 401);

  const url = Deno.env.get("SUPABASE_URL")!;
  const userClient = createClient(url, projectKey("SUPABASE_PUBLISHABLE_KEYS", "SUPABASE_ANON_KEY"), {
    global: { headers: { Authorization: `Bearer ${token}` } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data, error } = await userClient.auth.getUser(token);
  if (error || !data.user) return json({ error: "Not signed in" }, 401);
  const uid = data.user.id;

  const secretKey = projectKey("SUPABASE_SECRET_KEYS", "SUPABASE_SERVICE_ROLE_KEY");
  if (!secretKey) {
    console.error("No secret key available to the function");
    return json({ error: "Account deletion is not available right now." }, 503);
  }
  const admin = createClient(url, secretKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  // 2. Remove the user's private files (objects live under "<uid>/...").
  try {
    for (const bucket of BUCKETS) {
      const paths = await listFiles(admin, bucket, uid);
      for (let i = 0; i < paths.length; i += 100) {
        const { error: removeError } = await admin.storage.from(bucket).remove(paths.slice(i, i + 100));
        if (removeError) throw removeError;
      }
    }
  } catch (storageError) {
    console.error("Could not delete files", storageError instanceof Error ? storageError.message : "");
    return json({ error: "Could not delete your files. Please try again." }, 500);
  }

  // 3. Delete the account; all of the user's rows go with it.
  const { error: deleteError } = await admin.auth.admin.deleteUser(uid);
  if (deleteError) {
    console.error("Could not delete the user", deleteError.message);
    return json({ error: "Could not delete the account. Please try again." }, 500);
  }

  return json({ deleted: true });
});
