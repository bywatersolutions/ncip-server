[%- SET format_ValidToDate = config.format_ValidToDate || '%Y-%m-%d' -%]

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

<UniqueUserId>
<LookupId>[% config.lookup_user_id %]</LookupId>
    [%- SWITCH config.lookup_user_id -%]
    [%- CASE 'same' -%]
	<UserIdentifierValue>[% user_id | xml %]</UserIdentifierValue>
    [%- CASE 'cardnumber' -%]
	<UserIdentifierValue>[% user.userdata.cardnumber | xml %]</UserIdentifierValue>
    [%- CASE 'userid' -%]
	<UserIdentifierValue>[% user.userdata.userid | xml %]</UserIdentifierValue>
    [%- CASE -%]
        ERROR: lookup_user_id is set to an invalid value!
    [%- END -%]
</UniqueUserId>

[%# <UserFiscalAccount></UserFiscalAccount>
LoanedItemsCount
LoanedItem
RequestedItemsCount
RequestedItem
-%]

<UserOptionalFields>
    [%- FOREACH element IN elements -%]
        [%- IF element.textContent == 'Name Information' -%]
            <NameInformation>
                <PersonalNameInformation>
                    <StructuredPersonalUserName>
                        <GivenName>[% user.userdata.firstname | xml %]</GivenName>
                        <Surname>[% user.userdata.surname | xml %]</Surname>
                    </StructuredPersonalUserName>
                </PersonalNameInformation>
            </NameInformation>
        [%- END -%]

        [%- IF element.textContent == 'User Address Information' -%]
            <UserAddressInformation>
                <UserAddressRoleType>Home</UserAddressRoleType>
                <PhysicalAddress>
                    <StructuredAddress>
                        <Line1>[% FILTER collapse %][% user.userdata.streetnumber | xml %] [% user.userdata.address | xml %][% END %]</Line1>

                        [%- IF user.userdata.address2 -%]
                            <Line2>[% user.userdata.address2 | xml %]</Line2>
                        [%- END -%]

                        [%- IF user.userdata.city -%]
                            <Locality>[% user.userdata.city | xml %]</Locality>
                        [%- END -%]

                        [%- IF user.userdata.state -%]
                            <Region>[% user.userdata.state | xml %]</Region>
                        [%- END -%]

                        [%- IF user.userdata.zipcode -%]
                            <PostalCode>[% user.userdata.zipcode | xml %]</PostalCode>
                        [%- END -%]

                        [%- IF user.userdata.country -%]
                            <Country>[% user.userdata.country | xml %]</Country>
                        [%- END -%]
                    </StructuredAddress>
                    <PhysicalAddressType>Postal Address</PhysicalAddressType>
                </PhysicalAddress>
            </UserAddressInformation>

            [%- IF user.userdata.email -%]
                <UserAddressInformation>
                    <UserAddressRoleType>Home</UserAddressRoleType>
                    <ElectronicAddress>
                        <ElectronicAddressType>mailto</ElectronicAddressType>
                        <ElectronicAddressData>[% user.userdata.email %]</ElectronicAddressData>
                    </ElectronicAddress>
                </UserAddressInformation>
            [%- END -%]

            [%- IF user.userdata.phone -%]
                <UserAddressInformation>
                    <UserAddressRoleType>Home</UserAddressRoleType>
                    <ElectronicAddress>
                        <ElectronicAddressType>tel</ElectronicAddressType>
                        <ElectronicAddressData>[% user.userdata.phone %]</ElectronicAddressData>
                    </ElectronicAddress>
                </UserAddressInformation>
            [%- END -%]

            [%- IF user.userdata.phonepro || user.userdata.mobile -%]
                <UserAddressInformation>
                    <UserAddressRoleType>Mobile</UserAddressRoleType>
                    <ElectronicAddress>
                        <ElectronicAddressType>tel</ElectronicAddressType>
                        <ElectronicAddressData>[% user.userdata.phonepro || user.userdata.mobile %]</ElectronicAddressData>
                    </ElectronicAddress>
                </UserAddressInformation>
            [%- END -%]
        [%- END -%]

        [%- IF element.textContent == 'User Privilege' -%]
            <UserPrivilege>
                <AgencyUserPrivilegeType>LIBRARY</AgencyUserPrivilegeType>
                <UserPrivilegeStatus>
                    <UserPrivilegeStatusType>[% user.userdata.branchcode %]</UserPrivilegeStatusType>
                </UserPrivilegeStatus>
            </UserPrivilege>

            <UserPrivilege>
                <AgencyUserPrivilegeType>PROFILE</AgencyUserPrivilegeType>
                <UserPrivilegeStatus>
                    <UserPrivilegeStatusType>[% user.userdata.categorycode %]</UserPrivilegeStatusType>
                </UserPrivilegeStatus>
            </UserPrivilege>

            <UserPrivilege>
                <AgencyUserPrivilegeType>STATUS</AgencyUserPrivilegeType>
                <ValidToDate>[% user.userdata.dateexpiry_dt.strftime(format_ValidToDate) %]</ValidToDate>
                <UserPrivilegeStatus>
                    [%- FILTER collapse -%]
                        <UserPrivilegeStatusType>[%- FILTER collapse -%]
                                [%- IF user.userdata.restricted < 0 -%]
                                    Delinquent
                                [%- ELSIF user.userdata.restricted > 0 -%]
                                    Restricted
                                [%- ELSE -%]
                                    Ok
                                [%- END -%]
                        [%- END -%]</UserPrivilegeStatusType>
                    [%- END -%]
                </UserPrivilegeStatus>
            </UserPrivilege>
        [%- END -%]

        [%- IF user.userdata.restricted != 0 -%]
            <BlockOrTrap>
                <UniqueAgencyId>
                    <Value>[% from_agency %]</Value>
                </UniqueAgencyId>
                <BlockOrTrapType>
                    <Value>Block Check Out</Value>
                </BlockOrTrapType>
            </BlockOrTrap>
        [% END %]

    [%- END -%]

    [%- UNLESS config.do_not_include_user_identifier_primary_key -%]
        <UserId>
            <UserIdentifierType>Primary Key</UserIdentifierType>
            <UserIdentifierValue>[% user.userdata.borrowernumber %]</UserIdentifierValue>
        </UserId>
    [%- END -%]
</UserOptionalFields>
