# Deployment Strategy

## Overview

The application is deployed on an Azure VM as a Docker Compose stack. The Sinatra app runs on port `1010` inside the network, and nginx exposes the service publicly on port `80`.

## Release Flow

1. Build the image from [Dockerfile](../Dockerfile).
2. Deploy to the Azure VM prepared by [infrastructure/azure-setup.sh](../infrastructure/azure-setup.sh).
3. Start the production stack on the VM with `docker compose -f docker-compose.prod.yaml up -d`.
4. Start monitoring with `docker compose -f monitoring/docker-compose.yml up -d`.
5. Confirm the homepage, `/api/schema`, `/apidocs`, and `/metrics` endpoints work through nginx on the VM public IP.

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