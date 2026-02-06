# VPN HLS Proxy for Docker Swarm

## Why this repo exists

Deploying a VPN network on a Swarm is annoying due to restrictions in the permissions available to a Swarm Stack.
Running a WireGuard VPN on a Swarm Stack can be a bunch of hoops to jump through. This project aims to simplify that for combining a VPN connection along with an HLS proxy.

This project will use [gluetun](https://github.com/qdm12/gluetun) for the VPN configuration and [hls-proxy](https://github.com/Josh5/HLS-Proxy) for an HLS proxy.

## Detailed Overview

This repository provides a Docker Swarm “manager” service that orchestrates a child stack. The manager container runs with access to the Docker socket so it can create and update the internal VPN + HLS proxy stack in a predictable way, even within Swarm’s permission constraints. Configuration is supplied via environment variables, which are typically set in Portainer GitOps.

Key behaviors:

- The manager service bootstraps and maintains the child stack using the supplied config values.
- Updates are handled by re-running the manager with updated environment variables, which then reconciles the child stack.
- The HLS proxy runs inside the VPN network, ensuring traffic egresses through the VPN provider configured by Gluetun.

This structure makes it practical to operate a VPN-protected HLS proxy in Swarm, while keeping configuration in a single place and allowing GitOps-driven updates.

## Deployment (Portainer GitOps)

This repo publishes a Docker Swarm stack template to the `release/latest` branch via GitHub Actions. Use that branch in Portainer GitOps to deploy the stack with the built image.

1. In Portainer, create a new stack and select Git repository.
2. Set the repository reference to `refs/heads/release/latest`.
3. Set the compose file path to `docker-swarm-templates/docker-compose.vpn-hls-proxy.yml`.
4. Enable GitOps updates and set a polling interval (for example, 5 minutes).
5. In Environment variables (Advanced mode), paste the config block from the top of the compose file and edit for your environment.

The stack uses the published image `ghcr.io/josh5/vpn-hls-proxy-docker-swarm:latest` and manages child stacks via the Docker socket.

## Developing

From the root of this project, run these commands:

1) Create the development data directory
    ```
    mkdir -p ./tmp/data/sentry
    ```

2) Create a `.env` file
    ```
    cp -v ./examples/.env.example ./.env
    ```

3) Modify the `.env` file with whatever config options you need to modify

    Refer to the Docs:
    - [hls-proxy](https://github.com/Josh5/HLS-Proxy) (HLS Proxy Container)
    - [gluetun](https://github.com/qdm12/gluetun-wiki) (VPN Container)

    Only some options are configurable. Open an issue or PR if you need any additional functionality.

4) Build the docker image.
    ```
    sudo docker compose build
    ```

5) Run the dev compose stack
    ```
    sudo docker compose up -d
    ```
