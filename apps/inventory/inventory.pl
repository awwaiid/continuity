#!/usr/bin/perl

use strict;
use lib '../..';
use Continuity::Server::Simple;
use CGI qw/:html :form/;

# first load the DB tables
use Class::DBI::AutoLoader (
  dsn       => 'dbi:mysql:inventory',
  username  => 'root',
  password  => '',
  options   => { RaiseError => 1 },
  tables    => [qw( InventoryItem )],
  namespace => 'Database'
);

# Now load the components, which may build off of the DB classes
use InventoryItem;

# Set up and run the simple continuation server
my $server = Continuity::Server::Simple->new(
    port => 8080,
    new_cont_sub => \&main,
    app_path => '/app',
    debug => 3,
);

$server->loop;

sub getParsedInput {
  my $params = $server->get_request->params;
  foreach my $key (keys %$params) {
    if($key =~ /:|\[/) {
      my (@keys) = split /:|\[|\]\[|\]/, $key;
      my $val = $params->{$key}; 
      my $t = $params;
      my $key = pop @keys;
      while(my $k = shift @keys) {
        $t->{$k} = $t->{$k} || {};
        $t = $t->{$k};
      }
      $t->{$key} = $val;
    }
  }
  use Data::Dumper;
  print STDERR "Dump: " . Dumper($params);
  return $params;
}

#my $item = InventoryItem->create({
#  name => 'computer A',
#  serial => '345-6789Z'
#});

my $style = q|
  
  InventoryItem {
    edit: 0;
  }

  EditItem InventoryItem {
    edit: 1;
  }

|;

# ...
# $self->style('edit'); # Figure out our 'edit' style
#
#  finds it in
#   --->   $style->{InventoryItem}{childOf}{EditItem}{style}{edit} = 0;

sub editItem {
  my ($item) = @_;
  while(1) {
    # First we display the item
    print start_html('Edit item'),
          start_form(-action=>"/app"),
          h2('Edit item');
    print $item->toHTML({ edit => 1 });
    print qq{
      <input type=submit name="action:save" value="save">
      <input type=submit name="action:exit" value="exit">
    };
    print end_form();
    my $params = getParsedInput();
    if($params->{action}{save}) {
      $item->html_update($params);
      $item->update();
    }
    if($params->{action}{exit}) {
      return;
    }
  }
}

sub dispMain {
  print start_html('DB example'),
        start_form(-action=>"/app"),
        h2('List of inventory items');
  print qq{ <input type=submit name="action:add" value="Add"><br>\n};
  my @items = InventoryItem->retrieve_all;
  foreach my $item (@items) {
    print $item->toHTML({ edit => 0 });
    my $id = $item->id();
    print qq{ <input type=submit name="action:edit:$id" value="Edit">\n};
    print qq{ <input type=submit name="action:delete:$id" value="Delete"><br>\n};
  }
  print end_form();
  return getParsedInput();
}

sub firstKey {
  my ($hashref) = @_;
  my @keys = keys %$hashref;
  return shift @keys;
}

sub main {
  # Get and ignore first request
  $server->get_request;
  while(1) {
    my $params = dispMain();
    if($params->{action}{edit}) {
      my $id = firstKey($params->{action}{edit});
      my $item = InventoryItem->retrieve($id);
      editItem($item);
    }
    if($params->{action}{delete}) {
      my $id = firstKey($params->{action}{delete});
      my $item = InventoryItem->retrieve($id);
      $item->delete();
    }
    if($params->{action}{add}) {
      my $item = InventoryItem->create({});
      editItem($item);
    }
  }
}


