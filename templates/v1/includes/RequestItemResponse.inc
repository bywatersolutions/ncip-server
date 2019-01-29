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
        <Value>[% requestagency | xml %]</Value>
    </UniqueAgencyId>
    <RequestIdentifierValue>[% request_id | xml %]</RequestIdentifierValue>
</UniqueRequestId>
<UniqueUserId>
    <UniqueAgencyId>
        <Scheme>/ncip/v1_0/koha</Scheme>
        <Value>[% from_agency %]</Value>
    </UniqueAgencyId>
    <UserIdentifierValue>[% from_agency %]</UserIdentifierValue>
</UniqueUserId>
<RequestType>
    <Scheme>http://www.niso.org/ncip/v1_0/imp1/schemes/requesttype/requesttype.scm</Scheme>
    <Value>Loan</Value>
</RequestType>
<RequestScopeType>
    <Scheme>http://www.niso.org/ncip/v1_0/imp1/schemes/requestscopetype/requestscopetype.scm</Scheme>
    <Value>Bibliographic Item</Value>
</RequestScopeType>
