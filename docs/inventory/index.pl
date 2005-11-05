#!/usr/bin/perl

use strict;
use CServe::Client;
use CGI qw/:standard/;

# load the DB tables
use Class::DBI::AutoLoader (
  dsn       => 'dbi:mysql:inventory',
  username  => 'root',
  password  => 'vobo2Aje',
  options   => { RaiseError => 1 },
  tables    => [qw( InventoryItem )],
  namespace => 'Database'
);

=pod

Heres the schema (all ONE table!). You'll want to insert a few rows by hand.

CREATE TABLE `InventoryItem` (
  `inventoryItem_id` int(11) NOT NULL auto_increment,
  `serial` varchar(50) default NULL,
  `name` varchar(100) default NULL,
  PRIMARY KEY  (`inventoryItem_id`)
);

=cut

package InventoryItem;
use base 'Component::HTMLView';
use base 'Database::InventoryItem';

# So we need to document the CSS attributes this component understands
#    edit: boolean -- display as an editable thingie

sub toHTML {
  my ($self, $context) = @_;
  my $out;
  if(!$context->{'edit'}) {
    $out .=  "Item: ".$self->id." ".$self->name." (".$self->serial.")\n";
  } else {
    $out .= "Item Name: ".$self->html_text('name')."<br>\n";
    $out .= "Serial: ".$self->html_text('serial')."<br>\n";
  }
  # No matter what we get wrapped in a DIV
  $out = qq{ <div class="InventoryItem">$out</div> };
  return $out;
}

package main;
use strict;
use CServe::Client;
use CGI qw/:standard/;

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
          start_form(-action=>"http://localhost:8081/inventory/index.pl"),
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
        start_form(-action=>"http://localhost:8081/inventory/index.pl"),
        h2('List of inventory items');
  my @items = InventoryItem->retrieve_all;
  foreach my $item (@items) {
    print $item->toHTML({ edit => 0 });
    my $id = $item->id();
    print qq{ <input type=submit name="action:edit:$id" value="Edit"><br>\n};
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
  while(1) {
    my $params = dispMain();
    if($params->{action}{edit}) {
      my $id = firstKey($params->{action}{edit});
      my $item = InventoryItem->retrieve($id);
      editItem($item);
    }
  }
}

main();

