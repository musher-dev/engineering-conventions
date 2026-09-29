# platform-api

The product directory: the service's source, its build manifest (`go.mod`), its `Dockerfile` and its environment
contract (`env.schema.yaml`).

## Run the image

Each release publishes one image, tagged with the release's version without its `v` (`1.4.2` for the tag `v1.4.2`)
and attested by the Release workflow:

```sh
docker run ghcr.io/musher-dev/platform-api:<version>
```

Pin an exact version, or a digest, never a moving tag (OUT-11). A version before 1.0 bumps the minor for a breaking
change and the patch for anything else, so read the release notes before raising the minor. Verify an image's build
provenance with:

```sh
gh attestation verify oci://ghcr.io/musher-dev/platform-api:<version> --repo musher-dev/platform-api
```
