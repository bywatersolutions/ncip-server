[%- SET format_DateDue = config.format_DateDue || '%Y-%m-%dT%H:%M:%S' -%]
<ResponseHeader>
    <FromAgencyId>
        <UniqueAgencyId>
            <Scheme>texasgroup.worldcat.org/ncip/v1_0/ncip2/alpine</Scheme>
            <Value>[% from_agency | trim %]</Value>
        </UniqueAgencyId>
    </FromAgencyId>
    <ToAgencyId>
        <UniqueAgencyId>
            <Scheme>texasgroup.worldcat.org/ncip/v1_0/ncip2/alpine</Scheme>
            <Value>[% to_agency | trim %]</Value>
        </UniqueAgencyId>
    </ToAgencyId>
</ResponseHeader>
<UniqueItemId>
    <UniqueAgencyId>
        <Scheme>texasgroup.worldcat.org/ncip/v1_0/ncip2/alpine</Scheme>
        <Value>[% from_agency | trim %]</Value>
    </UniqueAgencyId>
    <ItemIdentifierValue>[% barcode | xml %]</ItemIdentifierValue>
</UniqueItemId>
<UniqueUserId>
    <UniqueAgencyId>
        <Scheme>texasgroup.worldcat.org/ncip/v1_0/ncip2/alpine</Scheme>
        <Value>[% to_agency | trim %]</Value>
    </UniqueAgencyId>
    <UserIdentifierValue>[% userid | xml %]</UserIdentifierValue>
</UniqueUserId>
<DateDue>[% datedue.strftime(format_DateDue) %]</DateDue>
