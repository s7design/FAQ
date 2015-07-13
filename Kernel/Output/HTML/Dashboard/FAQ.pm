# --
# Copyright (C) 2001-2015 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::Dashboard::FAQ;

use strict;
use warnings;

use Kernel::System::FAQ;

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    # get needed params
    for my $Needed (qw(Config Name UserID))
    {
        die "Got no $Needed!" if ( !$Self->{$Needed} );
    }

    return $Self;
}

sub Preferences {
    my ( $Self, %Param ) = @_;

    return;
}

sub Config {
    my ( $Self, %Param ) = @_;

    return (
        %{ $Self->{Config} },
    );
}

sub Run {
    my ( $Self, %Param ) = @_;

    # get FAQ object
    my $FAQObject = $Kernel::OM->Get('Kernel::System::FAQ');

    # set default interface settings
    $Self->{Interface} = $FAQObject->StateTypeGet(
        Name   => 'internal',
        UserID => $Self->{UserID},
    );
    $Self->{InterfaceStates} = $FAQObject->StateTypeList(
        Types  => $Kernel::OM->Get('Kernel::Config')->Get('FAQ::Agent::StateTypes'),
        UserID => $Self->{UserID},
    );

    # get layout object
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    $LayoutObject->FAQShowLatestNewsBox(
        FAQObject       => $FAQObject,
        Type            => $Self->{Config}->{Type},
        Mode            => 'Agent',
        CategoryID      => 0,
        Interface       => $Self->{Interface},
        InterfaceStates => $Self->{InterfaceStates},
        UserID          => $Self->{UserID},
    );
    my $Content = $LayoutObject->Output(
        TemplateFile => 'AgentDashboardFAQOverview',
        Data         => {
            CategoryID   => 0,
            SidebarClass => 'Medium',
        },
    );
    return $Content;
}

1;
