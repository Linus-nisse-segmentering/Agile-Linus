Backend deployment notes

Run on the private `backend` VM (no public IP). This starts the database, app, and monitoring stack privately.

1. Copy repository to backend VM (or `git clone`) and switch to the project folder.

2. Start backend services (app + db):

```bash
# on backend VM
docker compose -f docker-compose.backend.yaml up -d
```

3. Start monitoring (Prometheus + Grafana) on backend VM so they can resolve private DNS:

```bash
docker compose -f monitoring/docker-compose.yml up -d
```

4. Verify from the nginx VM (public) that private DNS resolves and the backend is reachable:

```bash
ssh azureuser@<nginx-public-ip>
# on nginx VM
host backend.backend.internal || nslookup backend.backend.internal
curl -sS http://backend.backend.internal:1010/health
```

5. Access Grafana and Prometheus via the public nginx reverse proxy (configure nginx to proxy /grafana and /prometheus paths).

Security notes:
- Do not publish Prometheus or Grafana host ports to the internet; use the nginx proxy to expose Grafana UI with authentication.
- Ensure NSG allows nginx VM private IP -> backend:1010 and backend -> DB:5432 only.
