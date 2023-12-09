package EliteTools::ID64;

use strict;
use warnings;

our $SECTOR_SIZE = 1280;
our $BASE_SECTOR_X = -49985;
our $BASE_SECTOR_Y = -40985;
our $BASE_SECTOR_Z = -24105;


sub new {
  my($type,$id) = @_;
  my $self =  {};
  bless $self,$type;

	$self->{id64} = $id;

  # clear body
  $id = $id << 9;
  $id = $id >> 9;

	$self->{masscode} = $id&7;
	$id = $id >> 3;

	my @boxel;
	my @sector;
	my $bitmask = (2**(7-$self->{masscode}))-1;

	for(my $i=0;$i<3;$i++)
  	{
	  $boxel[2-$i] = $id & $bitmask;
  	$id = $id >> (7-$self->{masscode});
#    $sector[2-$i] = ($id & (($i==1) ? 127 : 255));
		 $sector[2-$i] = ($id & (($i==1) ? 63 : 127));
    $id = $id >> (($i==1) ? 6 : 7);
    }
	# clear body
	$id = $id << 9;
	$id = $id >> 9;
	$self->{n2} = $id;
	$self->{sector} = EliteTools::Position->new(@sector);
	$self->{boxel} = EliteTools::Position->new(@boxel);
	return $self;
}

sub boxel { $_[0]->{boxel} }
sub sector { $_[0]->{sector} }
sub id64 { $_[0]->{id64} }
sub n2 { $_[0]->{n2} }
sub masscode_letter { chr(97 + $_[0]->{masscode}) }
sub masscode { $_[0]->{masscode} }
sub boxel_size { 2**$_[0]->{masscode} * 10 }
sub max_boxel_dimension { $SECTOR_SIZE / $_[0]->boxel_size }

# if $middle, return centre of boxel; otherwise bottom left front corner
sub get_coordinates {
	my($self,$middle) = @_;
	$middle |= 0;
	my $add = ($middle) ? $self->boxel_size / 2 : 0;
	my $ret = EliteTools::Position->new;
	$ret->x(($self->sector->x * $SECTOR_SIZE) + ($self->boxel->x * $self->boxel_size) + $BASE_SECTOR_X + $add);
  $ret->y(($self->sector->y * $SECTOR_SIZE) + ($self->boxel->y * $self->boxel_size) + $BASE_SECTOR_Y + $add);
  $ret->z(($self->sector->z * $SECTOR_SIZE) + ($self->boxel->z * $self->boxel_size) + $BASE_SECTOR_Z + $add);

	return $ret;
}


sub suggest_boxel_name {
  my $self = shift;

  my $sectornum = ($self->boxel->z * 16384) + ($self->boxel->y * 128) + $self->boxel->x;

  my $factor = int($sectornum / 17576);
  my $tmp = $sectornum - ($factor * 17576);
  my $w1 = $tmp % 26;
  $tmp -= $w1;
  $tmp /= 26;
  my $w2 = $tmp % 26;
  $tmp -= $w2;
  my $w3 = $tmp / 26;
  my $end = (($factor > 0) ? ($factor."-") : "").$self->n2;
  return chr($w1+65).chr($w2+65)."-".chr($w3+65)." ".$self->masscode_letter.$end;
}


package EliteTools::Position;

use strict;
use warnings;

sub new {
	my($type,$x,$y,$z) = @_;
  my $self =  {};
  bless $self,$type;

	$self->{x} = $x;
  $self->{y} = $y;
  $self->{z} = $z;
	return $self;
}

sub x { (defined $_[1]) ? ($_[0]->{x} = $_[1]) : $_[0]->{x}; }
sub y { (defined $_[1]) ? ($_[0]->{y} = $_[1]) : $_[0]->{y}; }
sub z { (defined $_[1]) ? ($_[0]->{z} = $_[1]) : $_[0]->{z}; }




1;




