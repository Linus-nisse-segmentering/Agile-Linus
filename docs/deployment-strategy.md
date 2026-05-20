# Deployment Strategy

## Overview

The application is deployed as a two-container Docker Compose stack. The Sinatra app runs on port `1010` inside the network, and nginx exposes the service publicly on port `80`.

## Release Flow

1. Build the image from [Dockerfile](../Dockerfile).
2. Validate the stack locally with `docker compose up --build`.
3. Deploy to the Azure VM prepared by [infrastructure/azure-setup.sh](../infrastructure/azure-setup.sh).
4. Refresh the compose stack on the host with `docker compose up -d --build`.
5. Confirm the homepage, `/api/schema`, and `/metrics` endpoints work through nginx.

## Rollback

Rollback is performed by redeploying the last known good commit on the host and restarting the compose stack. Because the app is containerized, rollback is a replace-and-restart operation rather than a manual server repair.

## SLA

- Availability target: 99.5% during class and demo windows.
- Recovery target: 15 minutes for a failed deploy.
- Monitoring target: any outage should be visible within one Prometheus scrape interval plus operator response time.

## Definition of Done

A release is complete only when:

- The Docker image builds successfully.
- nginx proxies traffic to the app container.
- The application responds on the public entrypoint.
- Prometheus can scrape `/metrics`.
- The deployment and rollback path are documented.