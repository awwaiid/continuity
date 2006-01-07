
package Template;

use Embperl;

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self = {};
  $self->{filename} = shift;
  bless $self, $class;
  while(@_) {
    $self->set(shift @_, shift @_);
  }
  return $self;
}

sub set
{
  my $self = shift;
  while(@_) {
    my $name = shift @_;
    my $val = shift @_;
    $self->{var}->{$name} = $val;
  }
  return $val;
}

sub render
{
  my $self = shift;
  my $filename = shift || $self->{filename};

  # Import all the vars into the Tpl namespace
  # There is probably a better way to do this!
  foreach $var (keys %{$self->{var}})
  {
    eval "\$Tpl::$var = \$self->{var}->{\$var};";
  }

  my $out;
  Embperl::Execute({
    'inputfile' => $filename,
    'package' => 'Tpl',
#    'escmode' => 3,
    'optDisableHtmlScan' => 1,
    'output' => \$out
  });

  # Kill all the vars we put into the Tpl namespace
  foreach $var (keys %{$self->{var}})
  {
    eval "\$Tpl::$var = undef;";
  }

  return $out;
}

1;
