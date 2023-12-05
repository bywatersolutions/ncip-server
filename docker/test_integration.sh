#!/bin/bash

function usage()
{
    echo "usage: test_integration.sh -v <version> [-i] | [-h]"
    echo "  -v --version     : The version of Koha to test against"
    echo "  -i --interactive : Leave containers running until a key is pressed"
}

interactive=
version=

while [ "$1" != "" ]; do
    case $1 in
        -v | --version )        shift
                                version=$1
                                ;;
        -i | --interactive )    interactive=true
                                ;;
        -h | --help )           usage
                                exit
                                ;;
        * )                     usage
                                exit 1
    esac
    shift
done

# Version is a required parameter
if [ -z "$version" ]
then
    usage
    exit 1
else
    echo "VERSION: ${version}"
fi

cd ..
NCIP_CLONE=$(pwd)
echo "NCIP CLONE: $NCIP_CLONE";
docker build --pull -f docker/Dockerfile --tag ncip-test-build .
cd docker

export LOCAL_USER_ID="$(id -u)" # Needed for koha-testing-docker

git clone --depth 5 https://git.koha-community.org/Koha-community/Koha.git -b "${version}" kohaclone
cd kohaclone
echo "KOHACLONE CONTENTS"
echo $(ls)
echo "GIT SHOW HEAD"
echo $(git log HEAD~1..HEAD)
# Grab the Koha version from Koha.pm
export KOHA_VER="$(cat Koha.pm | grep '$VERSION =')" && export KOHA_VER=${KOHA_VER%\"*} && export KOHA_VER=${KOHA_VER##*\"} && echo $KOHA_VER
IFS='.' read -ra VER_PARTS <<< "$KOHA_VER"

export KOHA_MAJOR=${VER_PARTS[0]}
export KOHA_MINOR=${VER_PARTS[1]}
# If the minor version is even, assume we are on master
if [ $((KOHA_MINOR%2)) -eq 0 ]; then export KOHA_BRANCH='master'; else export KOHA_BRANCH="$KOHA_MAJOR.$KOHA_MINOR"; fi
echo "MAJOR: $KOHA_MAJOR"
echo "MINOR: $KOHA_MINOR"
echo "BRANCH: $KOHA_BRANCH"

SYNC_REPO=$(echo `pwd`)
export SYNC_REPO=$(echo `pwd`)
echo "SYNC_REPO: $SYNC_REPO"
echo "SYNC REPO CONTENTS: $(ls -alh $SYNC_REPO)"
NCIP_CONF=$(echo $NCIP_CLONE/"docker/files/config.yml.template")

cd .. # Now set up koha-testing-docker
ls -alh
pwd
export LOCAL_USER_ID="$(id -u)" # Needed for koha-testing-docker
git clone https://gitlab.com/koha-community/koha-testing-docker.git
cd koha-testing-docker
git checkout origin/${KOHA_BRANCH} # Check out the correct koha-testing-docker branch
cp env/defaults.env .env
echo "CWD: $(pwd)";
echo "LS: $(ls -alh)";
echo "ENV: $(cat .env)";
docker-compose build
#sudo sysctl -w vm.max_map_count=262144
export KOHA_INTRANET_URL="http://127.0.0.1:8081"
export KOHA_MARC_FLAVOUR="marc21"
docker-compose down
docker-compose run koha &disown

cd .. # Now copy koha-conf.xml to somewhere the NCIP server can read it

echo "SLEEPING 5 MINUTES"
sleep 60
echo "1 MINUTE DONE"
sleep 60
echo "2 MINUTES DONE"
sleep 60
echo "3 MINUTES DONE"
sleep 60
echo "4 MINUTES DONE"
sleep 60
echo "5 MINUTES DONE"
echo "WAKING UP"

echo "DOCKER PS: $(docker ps)"
export KOHA_CONTAINER_ID=$(docker ps --filter "name=docker_koha_run" -q)
echo "KOHA CONTAINER $KOHA_CONTAINER_ID"

#docker exec $KOHA_CONTAINER_ID cat /etc/koha/sites/kohadev/koha-conf.xml > koha-conf.xml 2>&1
docker cp $KOHA_CONTAINER_ID:/etc/koha/sites/kohadev/koha-conf.xml koha-conf.xml
KOHA_CONF_PATH="$(pwd)/koha-conf.xml"
echo "KOHA CONF: $KOHA_CONF_PATH";
cat $KOHA_CONF_PATH

echo "SYNC_REPO: $SYNC_REPO"
echo "$(ls $SYNC_REPO)";
echo "KOHA_CONF_PATH: $KOHA_CONF_PATH"
echo "$(ls $KOHA_CONF_PATH)"
echo "NCIP_CONF: $NCIP_CONF"
echo "$(ls $NCIP_CONF)"

echo "DOCKER NETWORKS:"
echo $(docker network ls)

result=${PWD##*/}
if [ "$result" != "docker" ]; then
    echo "This script needs to be run from the docker directory"
    exit 1
fi

KOHA_DOCKER_NET=$(docker network ls -q -f "name=koha")

echo "STARTING NCIP CONTAINER"
NCIP_CONTAINER_ID=$(docker run -d \
        --net="$KOHA_DOCKER_NET" \
        --mount type=bind,source=$SYNC_REPO,target=/kohalib \
        --mount type=bind,source=$KOHA_CONF_PATH,target=/koha-conf.xml \
        --mount type=bind,source=$NCIP_CONF,target=/app/config.yml \
        ncip-test-build /app/docker/loop_forever.sh)

docker exec -t $NCIP_CONTAINER_ID mkdir -p /etc/koha/sites/kohadev/
docker exec -t $NCIP_CONTAINER_ID touch /etc/koha/sites/kohadev/log4perl.conf
docker exec -t $NCIP_CONTAINER_ID chmod 777 /etc/koha/sites/kohadev/log4perl.conf

echo "RUNNING NCIP UNIT TESTS"
docker exec -t $NCIP_CONTAINER_ID prove -r -v t
if [ $? == 0 ]
then
    echo "TESTS SUCCESSFUL!"
else
    echo "TEST FAILURE!"
    if [ "$interactive" != true ]
    then
        exit 1
    fi
fi

if [ "$interactive" == true ]
then
    read -p "Press any key to shut down containers and clean up... " -n1 -s
    # POST RUN CLEANUP
    docker rm -f $NCIP_CONTAINER_ID
    cd koha-testing-docker
    docker-compose down
    cd ..
    rm -rf koha-testing-docker
    rm -rf kohaclone
    rm -rf .env
    rm -rf koha-conf.xml
fi

