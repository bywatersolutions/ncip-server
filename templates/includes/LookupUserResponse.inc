<UserOptionalFields>
[% FOREACH element IN elements %]
  [% IF element.textContent == 'User Address Information' %]
     <PhysicalAddress>
       <StructuredAddress>
       <Line1>[% user.userdata.address1 %]</Line1>
       [% IF user.userdata.address2 %]
       <Line2>[% user.userdata.address2 %]</Line2>
       [% END %]
       [% IF user.userdata.city %]
       <Locality>[% user.userdata.city %]</Locality>
       [% END %]
       [% IF user.userdata.state %]
       <Region>[% user.userdata.state %]</Region>
       [% END %]
       [% IF user.userdata.zipcode %]
       <PostalCode>[% user.userdata.zipcode %]</PostalCode>
       [% END %]
       [% IF user.userdata.country %]
       <Country>[% user.userdata.country %]</Country>
       [% END %]
       </StructuredAddress>
     </PhysicalAddress>
  [% END %]
  [% IF element.textContent == 'Name Information' %]
    <NameInformation>
      <PersonalNameInformation>
        <StructuredPersonalUserName>
          <GivenName>[% user.userdata.firstname %]</GivenName>
          <Surname>[% user.userdata.surname %]</Surname>
        </StructuredPersonalUserName>
      </PersonalNameInformation>
    </NameInformation>
  [% END %]
[% END %]
</UserOptionalFields/>
