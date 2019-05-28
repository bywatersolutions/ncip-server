#!/bin/bash

usage()
{
    echo "usage: ncip-watcher.sh -c <container name> -p <patron identifier>"
}


ADDRESS=
CONTAINER=
PATRON=
VERBOSE=0

while [ "$1" != "" ]; do
    case $1 in
        -a | --address )
                                shift
                                ADDRESS=$1
                                ;;
        -c | --container )      shift
                                CONTAINER=$1
                                ;;
        -p | --patron )         shift
                                PATRON=$1
                                ;;
        -v | --verbose )        VERBOSE=1
                                ;;
        -h | --help )           usage
                                exit
                                ;;
        * )                     usage
                                exit 1
    esac
    shift
done

if [ "$ADDRESS" != "" ]; then
    if [ $VERBOSE == 1 ]; then
        echo "Connecting to address '$ADDRESS'"
    fi
else
    echo "Parameter -a --address is required";
    usage
    exit 1
fi

if [ "$CONTAINER" != "" ]; then
    if [ $VERBOSE == 1 ]; then
        echo "Checking container '$CONTAINER'"
    fi
else
    echo "Parameter -c --container is required";
    usage
    exit 1
fi

if [ "$PATRON" != "" ]; then
    if [ $VERBOSE == 1 ]; then
        echo "using patron '$PATRON'"
    fi
else
    echo "Parameter -p --patron is required";
    usage
    exit 1
fi

output=$(curl --max-time 15 -X POST -d "<?xml version='1.0' encoding='utf-8'?>
<NCIPMessage version='http://www.niso.org/schemas/ncip/v2_02/ncip_v2_02.xsd' xmlns='http://www.niso.org/2008/ncip'>
  <LookupUser>
    <InitiationHeader>
      <FromAgencyId>
        <AgencyId>CPomAG:massvc:HELM-QCC</AgencyId>
      </FromAgencyId>
      <ToAgencyId>
        <AgencyId>QCC_A</AgencyId>
      </ToAgencyId>
    </InitiationHeader>
    <AuthenticationInput>
      <AuthenticationInputData>$PATRON</AuthenticationInputData>
      <AuthenticationDataFormatType>Text</AuthenticationDataFormatType>
      <AuthenticationInputType>Barcode Id</AuthenticationInputType>
    </AuthenticationInput>
    <UserElementType>User Address Information</UserElementType>
    <UserElementType>Block Or Trap</UserElementType>
    <UserElementType>Name Information</UserElementType>
    <UserElementType>User Privilege</UserElementType>
  </LookupUser>
</NCIPMessage>
" $ADDRESS 2>&1 )

if [[ $output == *"<UserIdentifierValue>$PATRON</UserIdentifierValue>"* ]]; then
    if [ $VERBOSE == 1 ]; then
        echo "Received valid response from server."
    fi
else
    echo "Received invalid response"
    echo $output
    echo "Restarting $CONTAINER"
    docker restart $CONTAINER &
fi
