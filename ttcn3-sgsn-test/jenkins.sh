#!/bin/sh

. ../jenkins-common.sh
IMAGE_SUFFIX="${IMAGE_SUFFIX:-master}"
docker_images_require \
	"debian-jessie-build" \
	"osmo-sgsn-$IMAGE_SUFFIX" \
	"debian-stretch-titan" \
	"ttcn3-sgsn-test"

ADD_TTCN_RUN_OPTS=""
ADD_TTCN_RUN_CMD=""
ADD_TTCN_VOLUMES=""
SGSN_RUN_CMD="sgsn"
ADD_SGSN_VOLUMES=""
ADD_SGSN_ARGS=""
ADD_SGSN_RUN_OPTS=""

if [ "x$1" = "x-h" ]; then
	ADD_TTCN_RUN_OPTS="-ti"
	ADD_TTCN_RUN_CMD="bash"
	if [ -d "$2" ]; then
		ADD_TTCN_VOLUMES="$ADD_TTCN_VOLUMES -v $2:/osmo-ttcn3-hacks"
	fi
	if [ -d "$3" ]; then
		SGSN_RUN_CMD="sleep 9999999"
		ADD_SGSN_VOLUMES="$ADD_SGSN_VOLUMES -v $3:/osmo-sgsn"
		ADD_SGSN_RUN_OPTS="--privileged"
		set +x
		echo "

===== ATTENTION =====
Starting the osmo-sgsn-master docker image in hacking mode.
That means to launch the SGSN, you need to attach to it and start it manually:

  docker exec -ti nonjenkins-sgsn bash
  /# make

=====
"
		set -x
	fi
fi

network_create 172.18.8.0/24

mkdir $VOL_BASE_DIR/sgsn-tester
cp SGSN_Tests.cfg $VOL_BASE_DIR/sgsn-tester/

mkdir $VOL_BASE_DIR/sgsn
cp osmo-sgsn.cfg $VOL_BASE_DIR/sgsn/

mkdir $VOL_BASE_DIR/unix

echo Starting container with SGSN
docker run	--rm \
		--network $NET_NAME --ip 172.18.8.10 \
		-v $VOL_BASE_DIR/sgsn:/data \
		$ADD_SGSN_VOLUMES \
		--name ${BUILD_TAG}-sgsn -d \
		$ADD_SGSN_RUN_OPTS \
		$REPO_USER/osmo-sgsn-$IMAGE_SUFFIX \
		$SGSN_RUN_CMD

echo Starting container with SGSN testsuite
docker run	--rm \
		--network $NET_NAME --ip 172.18.8.103 \
		-e "TTCN3_PCAP_PATH=/data" \
		-v $VOL_BASE_DIR/sgsn-tester:/data \
		$ADD_TTCN_VOLUMES \
		--name ${BUILD_TAG}-ttcn3-sgsn-test \
		$ADD_TTCN_RUN_OPTS \
		$REPO_USER/ttcn3-sgsn-test \
		$ADD_TTCN_RUN_CMD

echo Stopping containers
docker container kill ${BUILD_TAG}-sgsn

network_remove
collect_logs
