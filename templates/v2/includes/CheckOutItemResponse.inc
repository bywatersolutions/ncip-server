[%- SET format_DateDue = config.format_DateDue || '%Y-%m-%dT%H:%M:%S' -%]
<ItemId>
    <AgencyId>[% from_agency | trim%]</AgencyId>
    <ItemIdentifierType>Barcode Id</ItemIdentifierType>
    <ItemIdentifierValue>[% barcode | xml %]</ItemIdentifierValue>
</ItemId>
<UserId>
    <AgencyId>[% to_agency | trim %]</AgencyId>
    <UserIdentifierType>Barcode Id</UserIdentifierType>
    <UserIdentifierValue>[% userid | xml %]</UserIdentifierValue>
</UserId>
<DateDue>[% datedue.strftime(format_DateDue) %]</DateDue>
