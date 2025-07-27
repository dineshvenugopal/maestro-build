# Running Maestro Studio in Docker

This document describes how to build and run Maestro Studio in a Docker container.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Docker Compose](https://docs.docker.com/compose/install/) (optional, but recommended)

## Building and Running with Docker Compose

The easiest way to build and run Maestro Studio is using Docker Compose:

```bash
# Build and start the container
docker-compose up -d

# View logs
docker-compose logs -f

# Stop the container
docker-compose down
```

Maestro Studio will be available at http://localhost:8000

## Building and Running with Docker

If you prefer to use Docker directly:

```bash
# Build the image with platform awareness
docker build --platform=$(docker info --format '{{.Architecture}}') -t maestro-studio .

# Alternative build command for Apple Silicon (M1/M2) or other ARM-based systems
# docker buildx build --platform linux/$(uname -m) -t maestro-studio .

# Run the container
docker run -p 8000:8000 --name maestro-studio -d maestro-studio

# View logs
docker logs -f maestro-studio

# Stop the container
docker stop maestro-studio
docker rm maestro-studio
```

Maestro Studio will be available at http://localhost:8000

## Configuration

The Docker container exposes port 8000 by default, but the actual port used by Maestro Studio is dynamically assigned. The container is configured to use port 8000 internally, but you can map it to a different port on your host if needed:

```bash
# Map to port 9000 on the host
docker-compose up -d
```

Or with Docker:

```bash
docker run -p 9000:8000 --name maestro-studio -d maestro-studio
```

Then Maestro Studio will be available at http://localhost:9000

## Troubleshooting

If you encounter issues:

1. Check the container logs:
   ```bash
   docker-compose logs -f
   ```
   or
   ```bash
   docker logs -f maestro-studio
   ```

2. Verify the container is running:
   ```bash
   docker-compose ps
   ```
   or
   ```bash
   docker ps
   ```

3. Check if the health check is passing:
   ```bash
   docker inspect --format='{{json .State.Health}}' maestro-studio | jq
   ```

## Notes

- The container runs with the `--no-window` flag to prevent it from trying to open a browser window.
- The container is configured to restart automatically unless explicitly stopped.
- The container uses a health check to verify that the server is running.