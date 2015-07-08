<ItemId>
    <AgencyId>[% fromagency | trim%]</AgencyId>
    <ItemIdentifierType>Barcode Id</ItemIdentifierType>
    <ItemIdentifierValue>[% barcode | xml %]</ItemIdentifierValue>
</ItemId>
<UserId>
    <AgencyId>[% toagency | trim %]</AgencyId>
    <UserIdentifierType>Barcode Id</UserIdentifierType>
    <UserIdentifierValue>[% userid | xml %]</UserIdentifierValue>
</UserId>
<DateDue>[% datedue %]</DateDue>
