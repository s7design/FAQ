# --
# Kernel/Output/HTML/DashboardFAQ.pm
# Copyright (C) 2001-2012 OTRS AG, http://otrs.org/
# --
# $Id: DashboardFAQ.pm,v 1.1 2012-06-06 08:27:46 mb Exp $
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::DashboardFAQ;

use strict;
use warnings;

use Kernel::System::FAQ;

use vars qw($VERSION);
$VERSION = qw($Revision: 1.1 $) [1];

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    # get needed objects
    for my $Object (
        qw(Config Name ConfigObject LogObject DBObject LayoutObject ParamObject UserID)
        )
    {
        die "Got no $Object!" if ( !$Self->{$Object} );
    }

    $Self->{FAQObject} = Kernel::System::FAQ->new(%Param);

    # set default interface settings
    $Self->{Interface} = $Self->{FAQObject}->StateTypeGet(
        Name   => 'internal',
        UserID => $Self->{UserID},
    );
    $Self->{InterfaceStates} = $Self->{FAQObject}->StateTypeList(
        Types  => $Self->{ConfigObject}->Get('FAQ::Agent::StateTypes'),
        UserID => $Self->{UserID},
    );

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

    $Self->{LayoutObject}->FAQShowLatestNewsBox(
        FAQObject       => $Self->{FAQObject},
        Type            => 'LastChange',
        Mode            => 'Agent',
        CategoryID      => 0,
        Interface       => $Self->{Interface},
        InterfaceStates => $Self->{InterfaceStates},
        UserID          => $Self->{UserID},
    );
    my $Content = $Self->{LayoutObject}->Output(
        TemplateFile => 'AgentDashboardFAQOverview',
        Data         => {
            CategoryID   => 0,
            SidebarClass => 'Medium',
        },
    );
    return $Content;
}

1;
