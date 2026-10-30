# 1Password Connect

The default secret path is a 1Password service account
(`OP_SERVICE_ACCOUNT_TOKEN`). It needs no server and can read 1Password
Environments. Connect is the alternative when many sessions would hit
service account rate limits.

| | Service account | Connect |
| --- | --- | --- |
| Infrastructure | none | this compose file, reachable by every agent |
| Rate limits | per token and per account | none after the first sync |
| 1Password Environments (`op run --environment`) | yes | no |
| `op` commands | all | `op run`, `op inject`, `op read`, `op item get` |

## Run it

1. Create the server and a token, granting only the vaults agents need:

   ```sh
   op connect server create <server-name> --vaults <vault>
   op connect token create <token-name> --server <server-name> --vault <vault>
   ```

   `server create` writes `1password-credentials.json` to the current
   directory. Move it next to `compose.yaml`.

2. Start it: `just connect-up` (or `docker compose -f connect/compose.yaml up -d`).

3. Check it:

   ```sh
   curl -H "Authorization: Bearer $OP_CONNECT_TOKEN" http://localhost:8080/v1/vaults
   ```

## Reach it from agents

Cloud sessions and CI runners need an HTTPS URL. Put Connect behind a
Cloudflare Tunnel or another reverse proxy, then set these on each
surface instead of `OP_SERVICE_ACCOUNT_TOKEN`:

```sh
OP_CONNECT_HOST=https://connect.example.com
OP_CONNECT_TOKEN=<token>
```

`bin/with-secrets` picks Connect when no service account token is set.
It ignores `OP_ENVIRONMENT_ID` under Connect, so use `--env-file` with
`op://` references instead.

The 1Password Connect token is a bearer credential with access to every
vault the server can read. Anyone who can use a Claude cloud environment
can read its variables, so scope the server to agent vaults only.
