#!/usr/bin/perl -w

################################################################################
# ping.pl daemon for probing the opensuse mirror server.
# Copyright (C) 2006 Martin Polster, Novell Inc.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA
################################################################################

use Net::Ping;
use DBI;
use strict;
use LWP::Simple;

my $verbose = 0;

my $dbh = DBI->connect( 'dbi:mysql:redirector', 'root', '',
    { PrintError => 0 } ) or die $DBI::errstr;

my $sql = qq{SELECT * FROM servers};
my $ary_ref  = $dbh->selectall_arrayref( $sql )
		   or die $dbh->errstr();

for my $row (@$ary_ref)
{
  my($id, $identifier, $baseurl, $baseurl_ftp, $status, 
     $status_url, $status_ftp, $status_ping) = @$row;

  my $srvn;
  
  if ($baseurl =~ m{://([^:/]+)} )
  {
    $srvn = $1;
  }
  else
  {
    warn "Can't parse baseurl $baseurl";
  }

  my $pingres = ping($identifier);

  my $content = head($baseurl);
  my $urlres = (defined $content ) ? 1 : 0;

  print "$identifier : $pingres : $content \n" if $verbose;

  $content = head($baseurl_ftp);
  my $ftpres = (defined $content ) ? 1 : 0;

  my $sql = "UPDATE servers SET status_ping = ?, status_baseurl = ?, 
	     status_baseurl_ftp = ? WHERE ( id = ?);";

  my $sth = $dbh->prepare( $sql );
     $sth->execute( $pingres, $urlres, $ftpres, $id );
}

$dbh->disconnect();
exit 0;

sub ping 
{
  my $host = shift;
  my $status = 0;

  my $p = Net::Ping->new();
  $status = 1 if $p->ping($host);
  $p->close();

  return $status;
}