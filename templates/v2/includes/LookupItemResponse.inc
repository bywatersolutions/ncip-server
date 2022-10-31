<ItemId>
    <ItemIdentifierValue>[% item.barcode | xml %]</ItemIdentifierValue>
</ItemId>
<UserOptionalFields>
    [% FOREACH element IN elements %]
        [% IF element.textContent == 'Bibliographic Description' %]
            <BibliographicDescription>
                <Author>[% item.biblio.author %]</Author>

                <BibliographicItemId>
                    <BibliographicItemIdentifier>[% item.biblio.isbn %]</BibliographicItemIdentifier>
                    <BibliographicItemIdentifierCode>ISBN</BibliographicItemIdentifierCode>
                </BibliographicItemId>

                <BibliographicRecordId>
                    <BibliographicRecordIdentifier>[% item.biblio.lccn %]</BibliographicRecordIdentifier>
                    <BibliographicRecordIdentifierCode>LCCN</BibliographicRecordIdentifierCode>
                </BibliographicRecordId>

                <Edition>[% item.biblio.editionstatement %]</Edition>
                <PlaceOfPublication>[% item.biblio.place %]</PlaceOfPublication>
                <PublicationDate>[% item.biblio.copyrightdate %]</PublicationDate>
                <Publisher>[% item.biblio.publishercode %]</Publisher>
                <Title>[% item.biblio.title %]</Title>
                [%- FILTER collapse -%]
                    <BibliographicLevel>
                        [%- FILTER trim -%]
                            [%- SWITCH item.record.leader.substr(7, 1) -%]
                            [%- CASE 'a' -%]
                                Monographic component part
                            [%- CASE 'b' -%]
                                Serial component part
                            [%- CASE 'c' -%]
                                Collection
                            [%- CASE 'd' -%]
                                Subunit
                            [%- CASE 'i' -%]
                                Integrating resource
                            [%- CASE 'm' -%]
                                Monograph
                            [%- CASE 's' -%] 
                                Serial
                            [%- END -%]
                        [%- END -%]
                    </BibliographicLevel>
                [%- END -%]
                <Language>[% item.record.field('008').data.substr(35,3) %]</Language>
                [%- FILTER collapse -%]
                    <MediumType>
                        [%- FILTER trim -%]
                            [%- SWITCH item.itemtype.sip_media_type -%]
                            [%- CASE '004' -%]
                                Audio tape
                            [%- CASE '001' -%]
                                Book
                            [%- CASE '010' -%]
                                Book with audio tape
                            [%- CASE '009' -%]
                                Book with CD
                            [%- CASE '008' -%]
                                Book with diskette
                            [%- CASE '003' -%]
                                Bound journal
                            [%- CASE '006' -%]
                                CD/CDROM
                            [% CASE '007' %]
                                Diskette
                            [% CASE '002' %]
                                Magazine
                            [% CASE '000' %]
                                Other
                            [% CASE '005' %]
                                Video tape
                            [%- END -%]
                        [%- END -%]
                    </MediumType>
                [%- END -%]
            </BibliographicDescription>
        [% END %]

        [% IF element.textContent == 'Circulation Status' %]
                [%- FILTER collapse -%]
                    <CirculationStatus>
                        [%- FILTER trim -%]
                            [% IF item.onloan %]
                                On Loan
                            [% ELSIF item.itemlost %]
                                Lost
                            [% ELSIF item.damaged %]
                                Missing
                            [% ELSIF item.notforlaon > 0 %]
                                Not Available
                            [% ELSIF item.notforlaon < 0 %]
                                On Order
                            [% ELSIF item.hold.found %]
                                Available For Pickup
                            [% ELSIF item.object.transfer %]
                                In Transit Between Library Locations
                            [% ELSE %]
                                Checked In
                            [% END %]
                        [%- END -%]
                    </CirculationStatus>
                [%- END -%]
        [% END %]

        [% IF element.textContent == 'Hold Queue Length' %]
            <HoldQueueLength>[% item.holds.size %]</HoldQueueLength>
        [% END %]

        [% IF element.textContent == 'Item Description' %]
            <CallNumber>[% item.itemcallnumber %]</CallNumber>
            <CopyNumber>[% item.itemcopynumber %]</CopyNumber>
        [% END %]
    [% END %]
</UserOptionalFields>
