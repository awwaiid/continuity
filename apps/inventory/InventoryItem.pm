
package InventoryItem;
use strict;
use lib '../..';
use base 'Continuity::Util::Component';
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

1;

