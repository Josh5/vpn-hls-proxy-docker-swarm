# Docker Swarm Stack Releases

## Portainer GitOps deployment

### Add a stack

1. Name the stack according the the docker-compose YAML file name in this repo.
1. Configure the stack to pull from a git repository.
1. Enter in the details for this repo.
   - Repository URL: `https://github.com/Josh5/vpn-hls-proxy-docker-swarm`
   - Repository reference: `refs/heads/release/latest`
1. Enter the name of the the docker-compose YAML file.
1. Enable GitOps updates.
1. Configure Polling updates with an interval of `5m`.
1. Configure Environment Variables. Refer to `**.env.example` files. Copy their contents into Portainer's **Environment variables** section (toggled to "Advanced mode") and edit as required.

### Notes

- The template expects access to the Docker socket to manage child stacks.
- The container image is published to GHCR by the GitHub Actions workflow in this repo.
