[%- SET format_DateDue = config.format_DateDue || '%Y-%m-%dT%H:%M:%S' -%]
<ResponseHeader>
    <FromAgencyId>
        <UniqueAgencyId>
            <Scheme>/ncip/v1_0/koha</Scheme>
            <Value>[% from_agency | trim %]</Value>
        </UniqueAgencyId>
    </FromAgencyId>
    <ToAgencyId>
        <UniqueAgencyId>
            <Scheme>/ncip/v1_0/koha</Scheme>
            <Value>[% to_agency | trim %]</Value>
        </UniqueAgencyId>
    </ToAgencyId>
</ResponseHeader>
<UniqueItemId>
    <UniqueAgencyId>
        <Scheme>/ncip/v1_0/koha</Scheme>
        <Value>[% from_agency | trim %]</Value>
    </UniqueAgencyId>
    <ItemIdentifierValue>[% barcode | xml %]</ItemIdentifierValue>
</UniqueItemId>
<UniqueUserId>
    <UniqueAgencyId>
        <Scheme>/ncip/v1_0/koha</Scheme>
        <Value>[% to_agency | trim %]</Value>
    </UniqueAgencyId>
    <UserIdentifierValue>[% userid | xml %]</UserIdentifierValue>
</UniqueUserId>
<DateDue>[% datedue.strftime(format_DateDue) %]</DateDue>
