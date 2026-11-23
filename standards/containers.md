# Containers

## Pull base images from AWS ECR Public, not Docker Hub

Use `public.ecr.aws/docker/library/<image>` instead of `docker.io/library/<image>` (or a bare `<image>`). They're the same official images, mirrored by AWS.

**Why:** Docker Hub rate-limits anonymous pulls. CI runners and deploy hosts share IPs, so builds fail at random when the limit is hit.

| Instead of | Use |
|------------|-----|
| `ruby:4.0.10-slim` | `public.ecr.aws/docker/library/ruby:4.0.10-slim` |
| `postgres:18` | `public.ecr.aws/docker/library/postgres:18` |
| `python:3.14-slim` | `public.ecr.aws/docker/library/python:3.14-slim` |
| `node:24-slim` | `public.ecr.aws/docker/library/node:24-slim` |
| `valkey/valkey:8` | `public.ecr.aws/valkey/valkey:8` |

This applies everywhere an image is named: `Dockerfile`, CI service containers, `docker-compose.yml`, and Kamal's `config/deploy.yml`.

Images that aren't "official" Docker library images (like `valkey/valkey`) are often published to ECR Public by their own maintainers. Search the [ECR Public Gallery](https://gallery.ecr.aws/) before falling back to Docker Hub.

## Pin versions

Always use an explicit version tag (`postgres:18`, not `postgres:latest`), so a rebuild can't change the database or runtime by surprise.

## Open question

- [ ] Kamal's own images (`basecamp/kamal-proxy`) still come from Docker Hub. Decide whether to mirror them to a private ECR repository.
