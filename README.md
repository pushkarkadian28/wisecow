# Wisecow: Containerization and Kubernetes Deployment

This repository is my submission for the Accuknox DevOps Trainee Practical Assessment, Problem Statement 1: containerize and deploy the Wisecow application on Kubernetes with CI/CD and TLS.

Original application: https://github.com/nyrahul/wisecow

## What Wisecow is

A single bash script, `wisecow.sh`, that listens on port 4499 and serves random fortune-cookie quotes wrapped in cowsay ASCII art over a raw TCP socket.

## What's in this repo

```
.
├── Dockerfile
├── wisecow.sh
├── k8s/
│   ├── deployment.yaml         # production, pulls from GHCR
│   ├── deployment.local.yaml   # local testing with Kind
│   ├── service.yaml
│   ├── ingress.yaml
│   └── cluster-issuer.yaml
├── .github/
│   └── workflows/
│       └── ci-cd.yaml
└── README.md
```

## Dockerization

The Dockerfile builds on `ubuntu:22.04`. Three dependency details worth flagging, since none of them are obvious from the original repo and each one broke the build during development:

- `fortune-mod` installs the engine but not the actual quote data. `fortunes-min` provides that separately.
- `cowsay` and `fortune` both install to `/usr/games`, which isn't on `PATH` by default in a non-login shell, so the Dockerfile adds it explicitly.
- `wisecow.sh` calls `nc -lN`. That `-N` flag belongs to netcat-openbsd. It is not provided by `nmap` or by Ncat, Ncat has no short `-N` option at all. The Dockerfile installs `netcat-openbsd` directly to match what the script expects.

Build and test locally:

```
docker build -t wisecow:local .
docker run -p 4499:4499 wisecow:local
curl http://localhost:4499
```

## Kubernetes Deployment

`k8s/deployment.yaml` runs 2 replicas with TCP-based readiness and liveness probes, since the app doesn't speak real HTTP so an HTTP probe won't work against it. `k8s/service.yaml` exposes it as a ClusterIP service on port 4499.

For local testing with Kind, use `k8s/deployment.local.yaml` instead, it points at a locally built image with `imagePullPolicy: Never` rather than pulling from a registry:

```
kind create cluster --name wisecow
docker build -t wisecow:local .
kind load docker-image wisecow:local --name wisecow
kubectl apply -f k8s/deployment.local.yaml
kubectl apply -f k8s/service.yaml
kubectl port-forward svc/wisecow-service 4499:4499
```

## CI/CD

`.github/workflows/ci-cd.yaml` has two jobs.

`build-and-push` runs automatically on every push to `main`. It builds the image and pushes it to GitHub Container Registry (`ghcr.io/<username>/wisecow`), tagged both `latest` and with the commit SHA. This job is fully automated and verified working.

`deploy` applies the updated image to a live cluster using a `KUBE_CONFIG` secret. It's set to trigger manually (`workflow_dispatch`) rather than automatically.

### Why deploy is manual, not automatic

The cluster used for development is a local Kind cluster running on my machine. GitHub Actions runners execute in GitHub's cloud and have no network path to `localhost` on a personal machine, no kubeconfig fix changes that. Automatic continuous deployment would require either a cluster with a public endpoint (a managed cluster on a cloud provider) or a self-hosted GitHub Actions runner with access to the local cluster. The deploy job itself is complete and functional, it's gated behind a manual trigger so it doesn't fail on every push against an unreachable target. Given a reachable cluster, removing the `if: github.event_name == 'workflow_dispatch'` condition restores full automatic CD.

## TLS

TLS is handled with cert-manager and an nginx ingress controller.

```
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.yaml
kubectl apply -f k8s/cluster-issuer.yaml
kubectl apply -f k8s/ingress.yaml
```

`cluster-issuer.yaml` uses a self-signed `ClusterIssuer`, appropriate for local testing. Add `127.0.0.1 wisecow.local` to `/etc/hosts` and test with:

```
curl -k https://wisecow.local
```

The `-k` flag is expected against a self-signed cert. For a real domain, swap the issuer for a Let's Encrypt ACME issuer and drop `-k`.

One caveat worth noting: `wisecow.sh` returns a bare `HTTP/1.1 200` line without real headers, it's not proper HTTP. Nginx ingress passes it through fine for demonstration purposes, but it won't behave like a normal web app under the ingress layer (no content-type negotiation, no keep-alive).

## Access

This repository is public per the assessment's access control requirement.
