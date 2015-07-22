# --
# Copyright (C) 2001-2015 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

# get selenium object
my $Selenium = $Kernel::OM->Get('Kernel::System::UnitTest::Selenium');

$Selenium->RunTest(
    sub {

        # get helper object
        my $Helper = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');

        # get FAQ object
        my $FAQObject = $Kernel::OM->Get('Kernel::System::FAQ');

        my $CategoryID = $FAQObject->CategoryAdd(
            Name     => 'Category' . $Helper->GetRandomID(),
            Comment  => 'Some comment',
            ParentID => 0,
            ValidID  => 1,
            UserID   => 1,
        );

        $Self->True(
            $CategoryID,
            "FAQ category is created - $CategoryID",
        );

        my $GroupID = $Kernel::OM->Get('Kernel::System::Group')->GroupLookup(
            Group => 'faq',
        );

        $FAQObject->SetCategoryGroup(
            CategoryID => $CategoryID,
            GroupIDs   => [$GroupID],
            UserID     => 1,
        );

        my @FAQSearch;

        # create test FAQs
        for my $Title (qw( FAQSearch FAQChangeSearch )) {
            for ( 1 .. 5 ) {

                # add test FAQ
                my $FAQTitle = $Title . $Helper->GetRandomID();
                my $FAQID    = $FAQObject->FAQAdd(
                    Title      => $FAQTitle,
                    CategoryID => $CategoryID,
                    StateID    => 1,
                    LanguageID => 1,
                    ValidID    => 1,
                    UserID     => 1,
                );

                $Self->True(
                    $FAQID,
                    "FAQ is created - $FAQID",
                );

                my %FAQ = (
                    FAQID    => $FAQID,
                    FAQTitle => $FAQTitle,
                    Type     => $Title,
                );

                push @FAQSearch, \%FAQ;
            }

        }

        # create test user and login
        my $TestUserLogin = $Helper->TestUserCreate(
            Groups => [ 'admin', 'users', 'faq', 'faq_admin' ],
        ) || die "Did not get test user";

        $Selenium->Login(
            Type     => 'Agent',
            User     => $TestUserLogin,
            Password => $TestUserLogin,
        );

        # get script alias
        my $ScriptAlias = $Kernel::OM->Get('Kernel::Config')->Get('ScriptAlias');

        # navigate to AgentFAQSearch form
        $Selenium->get("${ScriptAlias}index.pl?Action=AgentFAQSearch");

        # wait until form has loaded, if neccessary
        $Selenium->WaitFor( JavaScript => "return \$('#SearchProfile').length" );

        # check ticket search page
        for my $ID (
            qw(SearchProfile SearchProfileNew Attribute ResultForm SearchFormSubmit)
            )
        {
            my $Element = $Selenium->find_element( "#$ID", 'css' );
            $Element->is_enabled();
            $Element->is_displayed();
        }

        # add search filter by title and run it
        $Selenium->find_element( "#Attribute option[value='Title']",         'css' )->click();
        $Selenium->find_element( ".AddButton",                               'css' )->click();
        $Selenium->find_element( "Title",                                    'name' )->send_keys('FAQ*');
        $Selenium->find_element( "#Attribute option[value='CategoryIDs']",   'css' )->click();
        $Selenium->find_element( ".AddButton",                               'css' )->click();
        $Selenium->find_element( "#CategoryIDs option[value='$CategoryID']", 'css' )->click();
        $Selenium->find_element( "#SearchFormSubmit",                        'css' )->click();

        # wait until form has loaded, if neccessary
        $Selenium->WaitFor( JavaScript => "return \$('#OverviewBody').length" );

        # check AgentFAQSearch result screen
        $Selenium->find_element( "table",             'css' );
        $Selenium->find_element( "table thead tr th", 'css' );
        $Selenium->find_element( "table tbody tr td", 'css' );

        # check test FAQs searched by 'FAQ*'
        # all FAQs will be in a search result
        for my $FAQ (@FAQSearch) {

            # check if there is test FAQ on screen
            $Self->True(
                index( $Selenium->get_page_source(), $FAQ->{FAQTitle} ) > -1,
                "$FAQ->{FAQTitle} - found",
            );
        }

        # check 'Change search options' screen
        $Selenium->find_element( "#FAQSearch", 'css' )->click();

        # wait until form has loaded, if neccessary
        $Selenium->WaitFor( JavaScript => "return \$('#SearchProfile').length" );

        $Selenium->find_element( "Title",             'name' )->clear();
        $Selenium->find_element( "Title",             'name' )->send_keys('FAQChangeSearch*');
        $Selenium->find_element( "#SearchFormSubmit", 'css' )->click();

        # wait until form has loaded, if neccessary
        $Selenium->WaitFor( JavaScript => "return \$('#OverviewBody').length" );

        # check test FAQs searched by 'FAQChangeSearch*'
        # delete test FAQs after checking
        for my $FAQ (@FAQSearch) {

            if ( $FAQ->{Type} eq 'FAQChangeSearch' ) {

                # check if there is test FAQChangeSearch* on screen
                $Self->True(
                    index( $Selenium->get_page_source(), $FAQ->{FAQTitle} ) > -1,
                    "$FAQ->{FAQTitle} - found",
                );
            }
            else {

                # check if there is no test FAQSearch* on screen
                $Self->True(
                    index( $Selenium->get_page_source(), $FAQ->{FAQTitle} ) == -1,
                    "$FAQ->{FAQTitle} - not found",
                );
            }

            my $Success = $FAQObject->FAQDelete(
                ItemID => $FAQ->{FAQID},
                UserID => 1,
            );
            $Self->True(
                $Success,
                "FAQ is deleted - $FAQ->{FAQTitle}",
            );

        }

        # check 'Change search options' button again
        $Selenium->find_element( "#FAQSearch", 'css' )->click();

        # wait until form has loaded, if neccessary
        $Selenium->WaitFor( JavaScript => "return \$('#SearchProfile').length" );

        $Selenium->find_element( "Title",             'name' )->clear();
        $Selenium->find_element( "Title",             'name' )->send_keys('FAQChangeSearch*');
        $Selenium->find_element( "#SearchFormSubmit", 'css' )->click();

        # wait until form has loaded, if neccessary
        $Selenium->WaitFor( JavaScript => "return \$('#OverviewBody').length" );

        # check no data message
        $Selenium->find_element( "#EmptyMessageSmall", 'css' );
        $Self->True(
            index( $Selenium->get_page_source(), 'No FAQ data found.' ) > -1,
            "No FAQ data found.",
        );

        # delete test category
        my $Success = $FAQObject->CategoryDelete(
            CategoryID => $CategoryID,
            UserID     => 1,
        );

        $Self->True(
            $Success,
            "FAQ category is deleted - $CategoryID",
        );

        # make sure the cache is correct
        $Kernel::OM->Get('Kernel::System::Cache')->CleanUp( Type => "FAQ" );
    }
);

1;
