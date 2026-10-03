# The service image, in the product's docker/ directory (EC-0039). The build
# context is the product directory, trimmed by Dockerfile.dockerignore beside
# this file, so it holds only what the service needs. The Release workflow adds the OCI
# source, revision and version annotations when it pushes the image (OUT-10).
# The Go image's tag is an exact version (TOOL-07 checks it against the pin
# whenever .config/mise/config.toml pins go).
FROM golang:1.24.7 AS build
WORKDIR /src
COPY go.mod ./
COPY *.go ./
RUN CGO_ENABLED=0 go build -trimpath -o /out/platform-api .

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/platform-api /platform-api
ENTRYPOINT ["/platform-api"]
