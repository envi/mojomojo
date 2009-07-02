#!/usr/bin/env perl

BEGIN { $ENV{CATALYST_DEBUG} = 0 }
use strict;
use warnings;
use FindBin '$Bin';
use lib "$Bin/../../lib";
use MojoMojo::Schema;
use Config::JFDI;
use MojoMojo::Formatter::File;
use Path::Class ();
use Getopt::Long;
#use MojoMojo;
#use MojoMojo::Model::Search;


my($DIR, $URL_DIR, $EXCLUDE, $debug, $help);
GetOptions (  'dir=s'        => \$DIR,
              'urlbase=s'    => \$URL_DIR,
              'exclude=s'    => \$EXCLUDE,
              'debug'        => \$debug,
              'help'         => \$help ) or die &Usage;


$debug=0 if ( ! $debug);

# parametres fourni ?
if ( $help || ! $DIR || ! $URL_DIR ){
  &Usage;
  exit 1;
}

$DIR =~ s/\/$//;


#-----------------------------------------------------------------------------#
# Connect to database
#-----------------------------------------------------------------------------#
my $jfdi = Config::JFDI->new(name => "MojoMojo");
my $config = $jfdi->get;

my ($dsn, $user, $pass) = @ARGV;
eval {
    if (!$dsn) {
        ($dsn, $user, $pass) =
          @{$config->{'Model::DBIC'}->{'connect_info'}};
    };
};
if($@){
    die "Your DSN line in mojomojo.conf doesn't look like a valid DSN.".
      "  Add one, or pass it on the command line.";
}
die "No valid Data Source Name (DSN).\n" if !$dsn;
$dsn =~ s/__HOME__/$FindBin::Bin\/\.\./g;

my $schema = MojoMojo::Schema->connect($dsn, $user, $pass) or 
  die "Failed to connect to database";

my $person = $schema->resultset('Person')->find( 1 );





# Walk in $DIR
my $rootdir = Path::Class::dir($DIR);
my @files;
my $body;
my $urlpage;
$rootdir->recurse(callback => sub {
            my ($entry) = @_;
	    return if grep(/$EXCLUDE/, $entry );
            push @files, $entry unless ( $entry eq $DIR );
        });


my $exclude;
$exclude="exclude=$EXCLUDE" if $EXCLUDE;
createpage($URL_DIR, "{{dir $DIR $exclude}}", $person);

foreach my $f (@files){

  next if ( ! -r $f );
  $urlpage = $f;
  $urlpage =~ s/$DIR//;
  $urlpage =~ s/\./_/;
  $urlpage = "${URL_DIR}${urlpage}";

  if ( ref $f eq 'Path::Class::Dir'){
    $body = "{{dir $f $exclude}}";
  }
  else{
    my $plugin   = MojoMojo::Formatter::File->plugin($f);

    if ( $plugin ){
      $body = "{{file $plugin $f}}";
    }
    else {
      print STDERR "Can't find plugin for $f !!!\n";
      $body = "{{file UNKOWN_PLUGIN $f}}";
    }
  }

  createpage($urlpage,$body, $person);
}


# XXX: Update index_page (Model::Search)
sub createpage{
  my ($url, $body, $person) = @_;

  my ($path_pages, $proto_pages) = $schema->resultset('Page')->path_pages($url);

  $path_pages = $schema->resultset('Page')->create_path_pages(
    path_pages => $path_pages,
    proto_pages => $proto_pages,
    creator => $person->id,
  );

  my $page = $path_pages->[ @$path_pages - 1 ];

  my %content;
  $content{creator} = $person->id;
  $content{body}    = $body;


  $page->update_content(%content);
  #MojoMojo::Model::Search->index_page($page);
  $schema->resultset('Page')->set_paths($page);
  print "$url done\n";
}


#-----------------------------------------------------------------------------#
# Usage
#-----------------------------------------------------------------------------#
sub Usage{
  print "$0 --dir=DIRECTORY --url=URLBASE [--exclude=\"dir1 dir2\"] [--debug] [--help]\n";
  print "Ex: $0 --dir=/usr/share/perl/5.10/pod/ --url=/pod --exclude='\.svn|\.git'\n";
}