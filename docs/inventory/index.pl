#!/usr/bin/perl

use strict;
use CServe::Client;
use CGI qw/:standard/;

# load the DB tables
use Class::DBI::AutoLoader (
  dsn       => 'dbi:mysql:inventory',
  username  => 'root',
  password  => '',
  options   => { RaiseError => 1 },
  tables    => [qw( InventoryItem )],
  namespace => 'Database'
);

package Component::HTMLView;

use Data::Dumper;

sub html_input {
  my ($self, $field) = @_;
  my $out;
  my $id = $self->id;
  my $val = $self->$field;
  my $pkg = ref $self;
      print STDERR "$self name='$pkg:$id:$field'\n";
  $out .= qq{
    <input
      type="text"
      name="$pkg:$id:$field"
      id="$pkg:$id:$field"
      value="$val" />
  };
  return $out;
}

sub html_update {
  print STDERR "  " . Dumper(\@_) . "\n";
  my ($self, $field, $params) = @_;
  my $id = $self->id;
  my $val = $self->$field;
  my $pkg = ref $self;
  if(defined($params->{$pkg}{$id}{$field})) {
    print STDERR "Update: $pkg:$id:$field = $params->{$pkg}{$id}{$field}\n";
    $self->set($field, $params->{$pkg}{$id}{$field});
  }
}
  

package InventoryItem;
use base 'Component::HTMLView';
use base 'Database::InventoryItem';

# So we need to document the CSS attributes this component understands
#    edit: boolean -- display as an editable thingie

sub toString {
  my ($self, $context) = @_;
  my $out;
  if(!$context->{'edit'}) {
    $out =  "Item: ".$self->id." ".$self->name." (".$self->serial.")\n";
  } else {
    $out .= "Item Name: ".$self->html_input('name')."<br>\n";
    $out .= "Serial: ".$self->html_input('serial')."<br>\n";
  }
  return $out;
}

sub html_update {
  my ($self, $params) = @_;
  $self->SUPER::html_update('name', $params);
  $self->SUPER::html_update('serial', $params);
}

package Component;

sub new {
  my $self = {};
  bless $self;
  return $self;
}

sub get {
  my ($self, $name) = @_;
  return $self->{$name};
}

sub set {
  my ($self, $name, $val) = @_;
  return ($self->{$name} = $val);
}

package InventoryItem;
use base 'Component';

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

sub editItem {
  my ($item) = @_;
  while(1) {
    # First we display the item
    print start_html('Edit item'),
          start_form(-action=>"http://localhost:8081/inventory/index.pl"),
          h2('Edit item');
    print $item->toString({ edit => 1 });
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

sub main {
  # Call getParsedInput once to indicate that we are initialized
  print "hiya<br>";
  while(1) {
    print start_html('DB example'),
          start_form(-action=>"http://localhost:8081/inventory/index.pl"),
          h2('List of inventory items');
    my @items = InventoryItem->retrieve_all;
    foreach my $item (@items) {
      print $item->toString({ edit => 0 });
      my $id = $item->id();
      print qq{ <input type=submit name="action:edit:$id" value="Edit"><br>\n};
    }
    print end_form();
    my $params = getParsedInput();
    if($params->{action}{edit}) {
      my @k = keys %{$params->{action}{edit}};
      my $id = shift @k;
      my $item = InventoryItem->retrieve($id);
      editItem($item);
    }
  }
}

main();

