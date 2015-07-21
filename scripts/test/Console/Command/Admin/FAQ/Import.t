# --
# Copyright (C) 2001-2015 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

## no critic (Modules::RequireExplicitPackage)
use strict;
use warnings;
use utf8;

use vars (qw($Self));

my $CommandObject = $Kernel::OM->Get('Kernel::System::Console::Command::Admin::FAQ::Import');
my $HelperObject  = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');

# test command without source argument
my $ExitCode = $CommandObject->Execute();

$Self->Is(
    $ExitCode,
    1,
    "Option - without source argument",
);

my $SourcePath = $Kernel::OM->Get('Kernel::Config')->Get('Home') . "/scripts/test/sample/FAQ.csv";

$HelperObject->BeginWork();

# test command with source argument
$ExitCode = $CommandObject->Execute( '--separator', ';', '--quote', '', $SourcePath );

$Self->Is(
    $ExitCode,
    0,
    "Option - with source argument",
);

$HelperObject->Rollback();

1;
