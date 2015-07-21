# --
# Kernel/System/Console/Command/Admin/FAQ/Import.pm - console command
# Copyright (C) 2001-2015 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Admin::FAQ::Import;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('FAQ import tool.');
    $Self->AddOption(
        Name        => 'separator',
        Description => "Defines the separator for data in CSV file (default ',').",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'quote',
        Description => "Defines the  quote for data in CSV file (default '').",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddArgument(
        Name        => 'source',
        Description => "Specify the path to the file which containing FAQ items for importing.",
        Required    => 1,
        ValueRegex  => qr/.*/smx,
    );

    $Self->AdditionalHelp("<yellow>Format of the CSV file:\n
        \"title\";\"category\";\"language\";\"statetype\";\"field1\";\"field2\";\"field3\";\"field4\";\"field5\";\"field6\";\"keywords\"
        </yellow>\n");

    return;
}

sub PreRun {
    my ( $Self, %Param ) = @_;

    my $SourcePath = $Self->GetArgument('source');
    if ( $SourcePath && !-r $SourcePath ) {
        die "File $SourcePath does not exist, can not be read.\n";
    }

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Importing FAQ items...</yellow>\n");
    $Self->Print( "<yellow>" . ( '=' x 69 ) . "</yellow>\n" );

    my $SourcePath = $Self->GetArgument('source');
    $Self->Print("<yellow>Read File $SourcePath </yellow>\n\n");

    # read source file
    my $CSVStringRef = $Kernel::OM->Get('Kernel::System::Main')->FileRead(
        Location => $SourcePath,
        Result   => 'SCALAR',
        Mode     => 'binmode',
    );

    if ( !$CSVStringRef ){
        $Self->PrintError("Can't read file $SourcePath.\nImport aborted.\n");
        return $Self->ExitCodeError();
    }

    my $Separator = $Self->GetOption('separator') || ';';
    my $Quote = $Self->GetOption('quote') || '';

    # read CSV data
    my $DataRef = $Kernel::OM->Get('Kernel::System::CSV')->CSV2Array(
        String    => $$CSVStringRef,
        Separator => $Separator,
        Quote     => $Quote,
    );

    if ( !$DataRef ){
        $Self->PrintError("Error occurred. Import impossible! See Syslog for details.\n");
        return $Self->ExitCodeError();
    }

    # get FAQ object
    my $FAQObject = $Kernel::OM->Get('Kernel::System::FAQ');

    # get all FAQ language ids
    my %LanguageID = reverse $FAQObject->LanguageList(
        UserID => 1,
    );

    # get all state type ids
    my %StateTypeID = reverse %{ $FAQObject->StateTypeList( UserID => 1 ) };

    # get group id for FAQ group
    my $FAQGroupID = $Kernel::OM->Get('Kernel::System::Group')->GroupLookup(
        Group => 'faq',
    );

    my $LineCounter;
    my $SuccessCount;
    ROW:
    for my $RowRef ( @{$DataRef} ) {

        $LineCounter++;

        my (
            $Title, $CategoryString, $Language, $StateType,
            $Field1, $Field2, $Field3, $Field4, $Field5, $Field6, $Keywords
        ) = @{$RowRef};

        # check language
        if ( !$LanguageID{$Language} ) {
            $Self->PrintError("Error: Could not import line $LineCounter. Language '$Language' does not exist.\n");
            next ROW;
        }

        # check state type
        if ( !$StateTypeID{$StateType} ) {
            $Self->PrintError("Error: Could not import line $LineCounter. State '$StateType' does not exist.\n");
            next ROW;
        }

        # get subcategories
        my @CategoryArray = split /::/, $CategoryString;

        # check each subcategory if it exists
        my $CategoryID;
        my $ParentID = 0;

        # get database object
        my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

        for my $Category (@CategoryArray) {

            # get the category id
            $DBObject->Prepare(
                SQL => 'SELECT id FROM faq_category '
                    . 'WHERE valid_id = 1 AND name = ? AND parent_id = ?',
                Bind  => [ \$Category, \$ParentID ],
                Limit => 1,
            );
            my @Result;
            while ( my @Row = $DBObject->FetchrowArray() ) {
                push( @Result, $Row[0] );
            }
            $CategoryID = $Result[0];

            # create category if it does not exist
            if ( !$CategoryID ) {
                $CategoryID = $FAQObject->CategoryAdd(
                    Name     => $Category,
                    ParentID => $ParentID,
                    ValidID  => 1,
                    UserID   => 1,
                );

                # add new category to FAQ group
                $FAQObject->SetCategoryGroup(
                    CategoryID => $CategoryID,
                    GroupIDs   => [$FAQGroupID],
                    UserID     => 1,
                );
            }

            # set new parent id
            $ParentID = $CategoryID;
        }

        # check category
        if ( !$CategoryID ) {
            $Self->PrintError("Error: Could not import line $LineCounter. Category '$CategoryString' could not be created.\n");
            next ROW;
        }

        # convert StateType to State
        my %StateLookup = reverse $FAQObject->StateList( UserID => 1 );
        my $StateID;

        STATENAME:
        for my $StateName ( sort keys %StateLookup ) {
            if ( $StateName =~ m{\A $StateType }msxi ) {
                $StateID = $StateLookup{$StateName};
                last STATENAME;
            }
        }

        # add FAQ article
        my $FAQID = $FAQObject->FAQAdd(
            Title      => $Title,
            CategoryID => $CategoryID,
            StateID    => $StateID,
            LanguageID => $LanguageID{$Language},
            Field1     => $Field1,
            Field2     => $Field2,
            Field3     => $Field3,
            Field4     => $Field4,
            Field5     => $Field5,
            Field6     => $Field6,
            Keywords   => $Keywords || '',
            Approved   => 1,
            UserID     => 1,
        );

        # check success
        if ( $FAQID ) {
            $SuccessCount++;
        }
        else{
            $Self->PrintError("Error: Could not import line $LineCounter.\n");
        }
    }

    if( $SuccessCount ){
        $Self->Print("<green>Successfully imported $SuccessCount FAQ item(s).</green>\n\n");
    }

    $Self->Print("<green>Import complete.</green>\n");
    $Self->Print( "<yellow>" . ( '=' x 69 ) . "</yellow>\n" );
    $Self->Print("<green>Done.</green>\n");

    return $Self->ExitCodeOk();
}


1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the OTRS project (L<http://otrs.org/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (AGPL). If you
did not receive this file, see L<http://www.gnu.org/licenses/agpl.txt>.

=cut
