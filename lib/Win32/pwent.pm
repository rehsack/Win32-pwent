package Win32::pwent;

use warnings;
use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK);

use Exporter;
@ISA = qw(Exporter);
@EXPORT = qw();
@EXPORT_OK = qw(endgrent getpwent getpwnam getpwuid entgrent getgrent getgrname getgrgid);

use File::Spec;

use Win32;
use Win32::NetAdmin;
use Win32::Registry;
use Win32API::Net 0.13; # for USER_INFO_4 structure

=head1 NAME

Win32::pwent - The great new Win32::pwent!

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use Win32::pwent;

    my $foo = Win32::pwent->new();
    ...

=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

=head1 SUBROUTINES/METHODS

=head2 getpwent

see core doc

=head2 getpwnam

see core doc

=head2 getpwuid

see core doc

=head2 endpwent

see core doc

=head2 getgrent

see core doc

=head2 getgrnam

see core doc

=head2 getgrgid

see core doc

=head2 endgrent

see core doc

=cut

sub _fillpwent
{
    my %userInfo = @_;
    my $userName = $userInfo{name};
    my @pwent = ( @userInfo{'name', 'password', 'userId', 'primaryGroupId'}, undef, $userInfo{'comment'}, undef, $userInfo{'homeDir'} );
    if( defined( $userInfo{userSid} ) )
    {
        my $console;
        $::HKEY_USERS->Open( $userInfo{userSid} . "\\Console", $console );
        # find tree item - e.g. %SystemRoot%_system32_cmd.exe
        push( @pwent, File::Spec->catfile( $ENV{SystemRoot}, 'system32', 'cmd.exe' ) );
        unless( defined( $userInfo{homeDir} ) )
        {
            # complete from registry (HOMEDRIVE+HOMEPATH?, USERPROFILE?)
        }
    }
    else
    {
        push( @pwent, File::Spec->catfile( $ENV{SystemRoot}, 'system32', 'cmd.exe' ) );
    }

    return \@pwent;
}

sub _fillpwents
{
    my @pwents;
    my %users;
    Win32::NetAdmin::GetUsers( "", 0, \%users )
        or die "GetUsers() failed: $^E";
    foreach my $userName (keys %users)
    {
        my %userInfo;
        unless( Win32API::Net::UserGetInfo( "", $userName, 3, \%userInfo ) )
        {
            Win32API::Net::UserGetInfo( "", $userName, 4, \%userInfo )
                or die "UserGetInfo() failed: $^E";
            $userInfo{userId} = $1 if( $userInfo{userSid} =~ m/-(\d)$/ );
        }
        push( @pwents, _fillpwent( %userInfo ) );
    }

    return \@pwents;
}

my $pwents;
my $pwents_pos;

sub getpwent
{
    unless( "ARRAY" eq ref($pwents) )
    {
        $pwents = _fillpwents();
        $pwents_pos = 0;
    }
    my @pwent = @{$pwents->[$pwents_pos++]} if( $pwents_pos < scalar(@$pwents) );
    return wantarray ? @pwent : $pwent[2];
}

sub endpwent { $pwents = $pwents_pos = undef; }

sub getpwnam
{
    my $userName = $_[0];
    my %userInfo;
    unless( Win32API::Net::UserGetInfo( "", $userName, 3, \%userInfo ) )
    {
        Win32API::Net::UserGetInfo( "", $userName, 4, \%userInfo )
            or die "UserGetInfo() failed: $^E";
        $userInfo{userId} = $1 if( $userInfo{userSid} =~ m/-(\d+)$/ );
    }
    my $pwent = _fillpwent( %userInfo );
    return wantarray ? @$pwent : $pwent->[2];
}

sub getpwuid
{
    my $uid = $_[0];
    my $pwents = _fillpwents();
    my @uid_pwents = grep { $uid == $_->[2] } @$pwents;
    my @pwent = @{$uid_pwents[0]} if( 1 <= scalar(@uid_pwents) );
    return wantarray ? @pwent : $pwent[0];
}

sub _fillgrent
{
    my $grNam = $_[0];
    my %grInfo;
    unless( Win32API::Net::GroupGetInfo( "", $grNam, 2, \%grInfo ) )
    {
        Win32API::Net::GroupGetInfo( "", $grNam, 3, \%grInfo )
            or die "GroupGetInfo failed $^E";
        $grInfo{groupId} = $1 if( $grInfo{groupSid} =~ m/-(\d+)$/ );
    }
    my @grent = ( $grInfo{name}, undef, $grInfo{groupId} );
    my @grusers;
    Win32API::Net::GroupGetUsers( "", $grNam, \@grusers )
        or die "GroupGetUsers failed $^E";
    push( @grent, join( ' ', @grusers ) );
    return \@grent;
}

sub _fillgrents
{
    my @groupNames;
    Win32API::Net::GroupEnum( "", \@groupNames )
        or die "GroupEnum failed: $^E";
    my @grents;
    foreach my $groupName (@groupNames)
    {
        my $grent = _fillgrent($groupName);
        push( @grents, $grent );
    }
    return \@grents;
}

my $grents;
my $grents_pos;

sub getgrent
{
    unless( "ARRAY" eq ref($grents) )
    {
        $grents = _fillgrents();
        $grents_pos = 0;
    }
    my @grent = @{$grents->[$grents_pos++]} if( $grents_pos < scalar(@$grents) );
    return wantarray ? @grent : $grent[2];
}

sub endgrent { $grents = $grents_pos = undef; }

sub getgrnam
{
    my $groupName = $_[0];
    my $grent = _fillgrent( $groupName );
    return wantarray ? @$grent : $grent->[2];
}

sub getgrgid
{
    my $gid = $_[0];
    my $grents = _fillgrents();
    my @gid_grents = grep { $gid == $_->[2] } @$grents;
    my @grent = @{$gid_grents[0]} if( 1 <= scalar(@gid_grents) );
    return wantarray ? @grent : $grent[0];
}

=head1 AUTHOR

Jens Rehsack, C<< <rehsack at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-win32-pwent at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Win32-pwent>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Win32::pwent


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Win32-pwent>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Win32-pwent>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Win32-pwent>

=item * Search CPAN

L<http://search.cpan.org/dist/Win32-pwent/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2010 Jens Rehsack.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of Win32::pwent