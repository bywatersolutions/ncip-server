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
fi

cd ..
NCIP_CLONE=$(pwd)
docker build --pull -f docker/Dockerfile --tag ncip-test-build .
cd docker

export LOCAL_USER_ID="$(id -u)" # Needed for koha-testing-docker

git clone --depth 1 git://git.koha-community.org/koha.git -b 'v18.05.06' kohaclone
cd kohaclone
# Grab the Koha version from Koha.pm
export KOHA_VER="$(cat Koha.pm | grep '$VERSION =')" && export KOHA_VER=${KOHA_VER%\"*} && export KOHA_VER=${KOHA_VER##*\"} && echo $KOHA_VER
IFS='.' read -ra VER_PARTS <<< "$KOHA_VER"

export KOHA_MAJOR=${VER_PARTS[0]}
export KOHA_MINOR=${VER_PARTS[1]}
If the minor version is even, assume we are on master
if [ $((KOHA_MINOR%2)) -eq 0 ]; then export KOHA_BRANCH='master'; else export KOHA_BRANCH="$KOHA_MAJOR.$KOHA_MINOR"; fi
echo $KOHA_MAJOR
echo $KOHA_MINOR
echo $KOHA_BRANCH
cd .. # Now set up koha-testing-docker
ls -alh
pwd
export LOCAL_USER_ID="$(id -u)" # Needed for koha-testing-docker
git clone https://gitlab.com/koha-community/koha-testing-docker.git
cd koha-testing-docker
git checkout origin/${KOHA_BRANCH} # Check out the correct koha-testing-docker branch
cp env/defaults.env .env
docker-compose build
#sudo sysctl -w vm.max_map_count=262144
export KOHA_INTRANET_URL="http://127.0.0.1:8081"
export KOHA_MARC_FLAVOUR="marc21"
docker-compose down
docker-compose run koha &disown

cd .. # Now copy koha-conf.xml to somewhere the NCIP server can read it

echo "SLEEPING"
sleep 120
echo "WAKING UP"

export KOHA_CONTAINER_ID=$(docker ps --filter "name=koha-testing-docker_koha_run" -q)
echo "KOHA CONTAINER"
echo $KOHA_CONTAINER_ID

#docker exec -it $KOHA_CONTAINER_ID cp /etc/koha/sites/kohadev/koha-conf.xml /kohadevbox/koha/.
docker exec $KOHA_CONTAINER_ID cat /etc/koha/sites/kohadev/koha-conf.xml > koha-conf.xml 2>&1
sleep 5
echo "KOHA CONF";
cat koha-conf.xml

KOHA_CONF_DIR=$(echo `pwd`/"koha-conf.xml")
echo "KOHA CONF: $KOHA_CONF";
KOHACLONE=$(echo `pwd`/"kohaclone")
echo "KOHACLONE: $KOHACLONE";
NCIP_CONF=$(echo `pwd`/"files/config.yml.template")

NCIP_CONTAINER_ID=$(docker run -d \
        --net="koha-testing-docker_kohanet" \
        --mount type=bind,source=$KOHACLONE,target=/kohalib \
        --mount type=bind,source=$KOHA_CONF_DIR,target=/koha-conf.xml \
        --mount type=bind,source=$NCIP_CONF,target=/app/config.yml \
        ncip-test-build /app/docker/loop_forever.sh)

docker exec -t $NCIP_CONTAINER_ID prove t/01-NCIP.t

if [ "$interactive" == true ]
then
    read -p "Press any key to shut down containers and clean up... " -n1 -s
fi

# POST RUN CLEANUP
docker rm -f $NCIP_CONTAINER_ID
cd koha-testing-docker
docker-compose down
cd ..
rm -f koha-testing-docker
rm -rf kohaclone
rm -rf .env
rm -rf koha-conf.xml

