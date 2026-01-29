# Agent Guidance

When a user asks how to run the Cloudflare setup script, always include the prerequisites and links below before the
command block so they can quickly fetch the required values:

Prerequisites (Cloudflare)
- API token: https://dash.cloudflare.com/profile/api-tokens
- Select these permissions when creating the token:
  - Account > Cloudflare Tunnel > Edit
  - Account > Access: Apps and Policies > Edit
  - Account > Access: Organizations, Identity Providers, and Groups > Edit
  - Account > Access: Service Tokens > Edit
  - Zone > DNS > Edit
- Full permission list: https://developers.cloudflare.com/fundamentals/api/reference/permissions/
- Account ID + Zone ID: https://developers.cloudflare.com/fundamentals/account/find-account-and-zone-ids/
  (Account Home -> select site -> Overview -> API section)
