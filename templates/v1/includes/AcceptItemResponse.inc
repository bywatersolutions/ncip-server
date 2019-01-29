<ResponseHeader>
    <FromAgencyId>
        <UniqueAgencyId>
            <Scheme>/ncip/v1_0/koha</Scheme>
            <Value>[% from_agency %]</Value>
        </UniqueAgencyId>
    </FromAgencyId>
    <ToAgencyId>
        <UniqueAgencyId>
            <Scheme>/ncip/v1_0/koha</Scheme>
            <Value>[% to_agency %]</Value>
        </UniqueAgencyId>
    </ToAgencyId>
</ResponseHeader>
<UniqueRequestId>
        <UniqueAgencyId>
            <Scheme>/ncip/v1_0/koha</Scheme>
            <Value>[% from_agency %]</Value>
        </UniqueAgencyId>
        <RequestIdentifierValue>[% newbarcode | xml%]</RequestIdentifierValue>
</UniqueRequestId>
