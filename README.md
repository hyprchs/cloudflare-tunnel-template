# cloudflare-tunnel-template

Template repo for exposing a local service (UI or API) through Cloudflare Tunnel + Access.

This template provides a **starting point** (not a full setup) and instructions for making an arbitrary **self-hosted, Dockerized service**
available on a stable subdomain of your live Cloudflare-hosted website. This solves two main problems:

- Enables secure access to some local data without opening your entire machine to the public internet
- Provides stable URLs for tools that expect to be able to access your self-hosted services through permanent HTTPS endpoints

## Why this exists
At [Hyperchess](https://hyperchess.ai) ([GitHub](https://github.com/hyprchs/)), we tunnel a few key internal services to subdomains of https://hyperchess.ai:
- Viewers/dashboards for training data (https://trainingdata.hyperchess.ai)
- MLflow for training observability (https://mlflow.hyperchess.ai)
- Inference servers for chat completion requests, running on a local GPU! (https://api.hyperchess.ai)

This lets us self-host our full microservice stack during development (from a laptop!), keeping cloud costs at $0,
and progressively transition to cloud providers as-needed while we scale.

A few other notes:
- Subdomains will be protected by an auth check (current instructions show how to allow only `@hyperchess.ai` emails to log in, but this can be adjusted for your setup)
- Any paths that you mount to the local/self-hosted service's Docker container can be made available on the subdomain too (after auth; e.g. make your service read & display that data
  in a [frontend](https://github.com/jacksonthall22/sveltekit-supabase), or allow it to be downloaded via an S3-like API), bypassing the need for cloud storage!
- If your local container exposing the service isn't running, the live subdomain will simply be unavailable (giving a 503 error). That is, if you want to be extra sure
  your machine isn't exposed (even though the recommended setup is already secure), just stop the local container to break the tunnel.

## Quickstart
Note: These instructions were tested on Mac only.

### 1) Create a Cloudflare Tunnel
<ol type="a">
  <li>Go to <strong>Cloudflare Zero Trust</strong>, then go to <strong>Networks</strong> → <strong>Connectors</strong> → <strong>Create a tunnel</strong> → <strong>Select Cloudflared</strong></li>
  <li>Set a <strong>Tunnel name</strong>, e.g. <code>my-tunnel</code>, and click <strong>Save tunnel</strong></li>
  <li>Choose your environment (OS), <strong>Mac</strong></li>
  <li>If you do not already have <code>cloudflared</code> installed (check with <code>which cloudflared</code>), now is a good time to run <code>brew install cloudflared</code> as this page recommends</li>
  <li>
    Copy one of the code blocks to get the tunnel token. It isn't shown in full on this page, but you can paste the result somewhere, then copy the full token part.
    Create <code>.env</code> from <code>.env.example</code>:
    <pre><code>cp .env.example .env</code></pre>
    and paste in the token: <code>CLOUDFLARE_TUNNEL_TOKEN=&lt;token&gt;</code>. Back in Cloudflare, click <strong>Next</strong>.
  </li>
  <li>
    Under <strong>Hostname</strong>:
    <ul>
      <li>Set a value for <strong>Subdomain</strong>, e.g. <code>myservice</code></li>
      <li>Select your domain from the <strong>Domain</strong> dropdown, e.g. <code>&lt;your-domain&gt;.com</code>. Note: Your domain must be on Cloudflare and using Cloudflare DNS (nameservers pointed at Cloudflare), or the subdomain set in this step will not resolve correctly.</li>
    </ul>
    Under <strong>Service</strong>:
    <ul>
      <li>Select <strong>Type</strong>: <code>HTTP</code></li>
      <li>Set <strong>URL</strong>: <code>&lt;container-name&gt;:&lt;port&gt;</code>, e.g. <code>example-api:8000</code>. Here, <code>container-name</code> should be the name of your Docker service (which you'll need to set in <code>src/docker-compose.yml</code> next to the existing <code>cloudflared</code> service), and <code>port</code> should be the port that your service's container listens on. See <a href="example/">example/</a> for a minimal example setup.</li>
    </ul>
    Click <strong>Complete setup</strong>
  </li>
</ol>

### 2) Create a Service Token
<ol type="a">
  <li>While still in <strong>Cloudflare Zero Trust</strong>, go to <strong>Access controls</strong> → <strong>Service credentials</strong> → <strong>Create Service Token</strong></li>
  <li>
    <ul>
      <li>Set a <strong>Service token name</strong>, e.g. <code>my-service-token</code></li>
      <li>Select a <strong>Service Token Duration</strong>: <code>Non-expiring</code></li>
      <li>Click <strong>Generate token</strong></li>
      <li>Copy/save your <strong>Header and client secret</strong> for later, it's only available once on this screen.</li>
    </ul>
  </li>
</ol>

### 3) Enable One-time PIN identity provider
<ol>
  <li>While still in <strong>Cloudflare Zero Trust</strong>, go to <strong>Integrations</strong> → <strong>Identity providers</strong> → <strong>Add an identity provider</strong> → <strong>One-time PIN</strong>; it should show <strong>Added</strong>.</li>
</ol>

### 4) Create a Cloudflare Access app
<ol type="a">
  <li>While still in <strong>Cloudflare Zero Trust</strong>, go to <strong>Access controls</strong> → <strong>Applications</strong> → <strong>Add an application</strong> → <strong>Select Self-hosted</strong></li>
  <li>
    Under <strong>Basic information</strong>:
    <ul>
      <li>Set an <strong>Application name</strong>, e.g. <code>my-application</code></li>
      <li>Select a <strong>Session Duration</strong> that works for you, e.g. <code>24 hours</code>. This sets the auth session duration for when visiting <code>myservice.&lt;your-domain&gt;.com</code>, after which you'll need to sign in again.</li>
      <li>Click <strong>Add public hostname</strong>, then set values under it:</li>
      <li>
        <ul>
          <li>Select <strong>Input method</strong>: <code>Default</code></li>
          <li>Set <strong>Subdomain</strong> to the same value as before, e.g. <code>myservice</code></li>
          <li>Set <strong>Domain</strong> to the same value as before, e.g. <code>&lt;your-domain&gt;.com</code></li>
        </ul>
      </li>
    </ul>
    Under <strong>Access policies</strong>, we'll create two new policies:
    <ul>
      <li>Policy 1:</li>
      <li>
        <ul>
          <li>Click <strong>Create new policy</strong>. This will open a new tab.</li>
          <li>Under <strong>Basic Information</strong>:</li>
          <li>
            <ul>
              <li>Set <strong>Policy name</strong>: <code>Humans/browser</code></li>
              <li>Select <strong>Action</strong>: <code>Allow</code></li>
              <li>Select <strong>Session duration</strong>: <code>Same as application session timeout</code></li>
            </ul>
          </li>
          <li>Under <strong>Add rules</strong> → <strong>Include (OR)</strong>:</li>
          <li>
            <ul>
              <li>Define who you want to be able to get through the auth guard at your service in the browser. For example, select <strong>Selector</strong>: <code>Emails</code>, and enter specific emails in <strong>Value</strong>, or select <strong>Selector</strong>: <code>Emails ending in</code> with <strong>Value</strong>: <code>@&lt;your-company&gt;.com</code>.</li>
            </ul>
          </li>
          <li>Click <strong>Save</strong> and go back to the previous tab</li>
          <li>Click <strong>Select existing policies</strong> and choose the policy you just created</li>
        </ul>
      </li>
      <li>Policy 2:</li>
      <li>
        <ul>
          <li>Click <strong>Create new policy</strong>. This will open a new tab.</li>
          <li>Under <strong>Basic Information</strong>:</li>
          <li>
            <ul>
              <li>Set <strong>Policy name</strong>: <code>Jobs/non-interactive</code></li>
              <li>Select <strong>Action</strong>: <code>Service Auth</code></li>
              <li>Select <strong>Session duration</strong>: <code>No duration, expires immediately</code></li>
            </ul>
          </li>
          <li>Under <strong>Add rules</strong> → <strong>Include (OR)</strong>:</li>
          <li>
            <ul>
              <li>Select <strong>Selector</strong>: <code>Service Token</code></li>
              <li>Select <strong>Value</strong> as the token name you created earlier, e.g. <code>my-service-token</code></li>
            </ul>
          </li>
          <li>Click <strong>Save</strong> and go back to the previous tab</li>
          <li>Click <strong>Select existing policies</strong> and choose the policy you just created</li>
        </ul>
      </li>
    </ul>
    Under <strong>Login methods</strong>:
    <ul>
      <li>Turn on <strong>Accept all available identity providers</strong>. You should see <strong>One-time PIN</strong> availabe in the list below.</li>
    </ul>
    Click <strong>Next</strong>
    <br />
    Optional: Under <strong>Application Appearance</strong>, select <strong>Use custom logo</strong> and provide link to your website's favicon!
    <br />
    TODO: recommend good <strong>Cross-Origin Resource Sharing (CORS) settings</strong>
    <br />
    TODO: recommend good <strong>Cookie settings</strong>
    <br />
    TODO: recommend good <strong>401 Response for Service Auth policies</strong>
    <br />
    Click <strong>Save</strong>
  </li>
</ol>

### 5) Update `src/cloudflared.yml`
<ul>
  <li>Set <code>hostname</code> to your public hostname (example: <code>&lt;subdomain&gt;.&lt;your-domain&gt;.com</code>)</li>
  <li>Replace <code>&lt;your-domain&gt;</code> with your Cloudflare-managed domain</li>
  <li>Replace <code>&lt;subdomain&gt;</code> with the subdomain you want to expose</li>
  <li>Set <code>service</code> to your local Dockerized service</li>
  <li>
    <ul>
      <li>Replace <code>&lt;port&gt;</code> with the port your local service's container listens on</li>
      <li>Replace <code>&lt;container-name&gt;</code> with your local service's name on the same Docker network (e.g. <code>http://example-api:8000</code>)</li>
    </ul>
  </li>
  <li>TODO: Simplify/edit instructions above to read more similarly to previous steps (check against <code>src/cloudflared.yml</code> to be sure these instructions are still accurate and minimal)</li>
</ul>

### 6) Start the tunnel
```bash
docker compose -f src/docker-compose.yml up -d
```

## Project structure
- `src/` — template cloudflared config + compose file
- `example/` — standalone FastAPI example (with its own README)
