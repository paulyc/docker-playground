#!/bin/sh

. ../jenkins-common.sh
IMAGE_SUFFIX="${IMAGE_SUFFIX:-master}"
docker_images_require \
	"debian-jessie-build" \
	"osmo-hlr-$IMAGE_SUFFIX" \
	"debian-stretch-titan" \
	"ttcn3-hlr-test"

ADD_TTCN_RUN_OPTS=""
ADD_TTCN_RUN_CMD=""
ADD_TTCN_VOLUMES=""

if [ "x$1" = "x-h" ]; then
	ADD_TTCN_RUN_OPTS="-ti"
	ADD_TTCN_RUN_CMD="bash"
	if [ -d "$2" ]; then
		ADD_TTCN_VOLUMES="$ADD_TTCN_VOLUMES -v $2:/osmo-ttcn3-hacks"
	fi
fi

network_create 172.18.10.0/24

mkdir $VOL_BASE_DIR/hlr-tester
cp HLR_Tests.cfg $VOL_BASE_DIR/hlr-tester/

mkdir $VOL_BASE_DIR/hlr
cp osmo-hlr.cfg $VOL_BASE_DIR/hlr/

echo Starting container with HLR
docker run	--rm \
		--network $NET_NAME --ip 172.18.10.20 \
		-v $VOL_BASE_DIR/hlr:/data \
		--name ${BUILD_TAG}-hlr -d \
		$REPO_USER/osmo-hlr-$IMAGE_SUFFIX \
		osmo-hlr

echo Starting container with HLR testsuite
docker run	--rm \
		--network $NET_NAME --ip 172.18.10.103 \
		-e "TTCN3_PCAP_PATH=/data" \
		-v $VOL_BASE_DIR/hlr-tester:/data \
		$ADD_TTCN_VOLUMES \
		--name ${BUILD_TAG}-ttcn3-hlr-test \
		$ADD_TTCN_RUN_OPTS \
		$REPO_USER/ttcn3-hlr-test \
		$ADD_TTCN_RUN_CMD

echo Stopping containers
docker container kill ${BUILD_TAG}-hlr

network_remove
collect_logs
