SHORT_NAME ?= workflow-migration

include versioning.mk

# dockerized development environment variables
REPO_PATH := github.com/deis/${SHORT_NAME}
DEV_ENV_IMAGE := quay.io/deis/go-dev:0.20.0
DEV_ENV_WORK_DIR := /go/src/${REPO_PATH}
DEV_ENV_PREFIX := docker run --rm -v ${CURDIR}:${DEV_ENV_WORK_DIR} -w ${DEV_ENV_WORK_DIR}
DEV_ENV_CMD := ${DEV_ENV_PREFIX} ${DEV_ENV_IMAGE}

# SemVer with build information is defined in the SemVer 2 spec, but Docker
# doesn't allow +, so we use -.
BINARY_DEST_DIR := rootfs/usr/bin
# Common flags passed into Go's linker.
LDFLAGS := "-s -w -X main.version=${VERSION}"
# Docker Root FS
BINDIR := ./rootfs

all:
	@echo "Use a Makefile to control top-level building of the project."

# you need to strip the vendor because k8s doesn't use glide https://github.com/kubernetes/kubernetes/issues/25572
bootstrap:
	${DEV_ENV_CMD} glide install --strip-vendor

glideup:
	${DEV_ENV_CMD} glide up

# This illustrates a two-stage Docker build. docker-compile runs inside of
# the Docker environment. Other alternatives are cross-compiling, doing
# the build as a `docker build`.
build-binary:
	${DEV_ENV_CMD} sh -c 'go build -ldflags ${LDFLAGS} -o ${BINARY_DEST_DIR}/boot boot.go; upx -9 ${BINARY_DEST_DIR}/boot'

test:
	${DEV_ENV_CMD} sh -c 'go test $$(glide nv)'

build: build-binary
	docker build --rm -t ${IMAGE} rootfs
	docker tag ${IMAGE} ${MUTABLE_IMAGE}

.PHONY: all build push test
