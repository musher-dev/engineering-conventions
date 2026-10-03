# syntax=docker/dockerfile:1
FROM golang:1.25.1-alpine AS build
WORKDIR /src
COPY go.mod main.go ./
RUN go build -o /out/api .

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/api /api
ENTRYPOINT ["/api"]
