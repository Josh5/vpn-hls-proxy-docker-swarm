# VPN HLS Proxy for Docker Swarm

## Why this repo exists

Deploying a VPN network on a Swarm is annoying due to restrictions in the permissions available to a Swarm Stack.
Running a WireGuard VPN on a Swarm Stack can be a bunch of hoops to jump through. This project aims to simplify that for combining a VPN connection along with an HLS proxy.

This project will use [gluetun](https://github.com/qdm12/gluetun) for the VPN configuration and [hls-proxy](https://github.com/Josh5/HLS-Proxy) for an HLS proxy.

## Installation

Use one of the templates provided or fork and roll your own.

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
