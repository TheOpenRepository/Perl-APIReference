package Perl::APIReference;

use 5.006;
use strict;
use warnings;
use Carp qw/croak/;
use version;

our $VERSION = '0.07';

use Class::XSAccessor
  getters => {
    'index' => 'index',
    'perl_version' => 'perl_version',
  };

sub _par_loader_hint {
  require Perl::APIReference::Generator;
  require Perl::APIReference::V5_014_001;
}

our %Perls = (
  5.015001 => 'V5_015_001',
  5.014001 => 'V5_014_001',
  5.014    => 'V5_014_000',
  5.012004 => 'V5_012_004',
  5.012003 => 'V5_012_003',
  5.012002 => 'V5_012_002',
  5.012001 => 'V5_012_001',
  5.012000 => 'V5_012_000',
  5.01     => 'V5_010_000',
  5.010001 => 'V5_010_001',
  5.008009 => 'V5_008_009',
  5.008008 => 'V5_008_008',
  5.008007 => 'V5_008_007',
  5.008006 => 'V5_008_006',
  5.008005 => 'V5_008_005',
  5.008004 => 'V5_008_004',
  5.008003 => 'V5_008_003',
  5.008002 => 'V5_008_002',
  5.008001 => 'V5_008_001',
  5.008    => 'V5_008_000',
  5.006002 => 'V5_006_002',
  5.006001 => 'V5_006_001',
  5.006    => 'V5_006_000',
);

our $NewestAPI       = '5.015001';
our $NewestStableAPI = '5.014001';

$Perls{'5.014000'} = $Perls{5.014};
$Perls{'5.012000'} = $Perls{5.012};
$Perls{'5.010000'} = $Perls{5.01};
$Perls{'5.010'}    = $Perls{5.01};
$Perls{'5.008000'} = $Perls{5.008};
$Perls{'5.008000'} = $Perls{5.006};
#$Perls{'5.000'} = $Perls{5};

sub _get_class_name {
  my $class_or_self = shift;
  my $version = shift;
  return exists $Perls{$version} ? "Perl::APIReference::" . $Perls{$version} : undef;
}

sub new {
  my $class = shift;
  my %args = @_;
  my $perl_version = $args{perl_version};
  croak("Need perl_version")
    if not defined $perl_version;
  $perl_version = $NewestStableAPI if lc($perl_version) eq "newest";
  $perl_version = $NewestAPI if lc($perl_version) eq "newest_devel";

  $perl_version = version->new($perl_version)->numify();
  croak("Bad perl version '$perl_version'")
    if not exists $Perls{$perl_version};

  my $classname = __PACKAGE__->_get_class_name($perl_version);
  eval "require $classname;";
  croak("Bad perl version ($@)") if $@;

  return $classname->new(perl_version => $perl_version);
}

sub as_yaml_calltips {
  my $self = shift;

  my $index = $self->index();
  my %toyaml;
  foreach my $entry (keys %$index) {
    my $yentry = {
      cmd => '',
      'exp' => $index->{$entry}{text},
    };
    $toyaml{$entry} = $yentry;
  }
  require YAML::Tiny;
  return YAML::Tiny::Dump(\%toyaml);
}

# only for ::Generator
sub _new_from_parse {
  my $class = shift;

  return bless {@_} => $class;
}

# only for ::Generator
sub _dump_as_class {
  my $self = shift;
  my $version = $self->perl_version;
  my $classname = $self->_get_class_name($version);
  if (not defined $classname) {
    die "Can't determine class name for Perl version '$version'."
      . " Do you need to add it to the list of supported versions first?";
  }
  my $file_name = $classname;
  $file_name =~ s/^.*::([^:]+)$/$1.pm/;
  
  require Data::Dumper;
  local $Data::Dumper::Indent = 0;
  my $dumper = Data::Dumper->new([$self->{'index'}]);
  my $dump = $dumper->Dump();
  
  open my $fh, '>', $file_name or die $!;
  print $fh <<HERE;
package $classname;
use strict;
use warnings;
use parent 'Perl::APIReference';

sub new {
  my \$class = shift;
  my \$VAR1;

do{$dump};

  my \$self = bless({
    'index' => \$VAR1,
    perl_version => '$version',
  } => \$class);
  return \$self;
}

1;
HERE
}


1;
__END__

=head1 NAME

Perl::APIReference - Programmatically query the perlapi

=head1 SYNOPSIS

  use Perl::APIReference;
  my $api = Perl::APIReference->new(perl_version => '5.12.4');
  my $api_index_hash = $api->index;

=head1 DESCRIPTION

This module allows accessing the perlapi documentation for multiple
releases of perl as an index (a hash).

Currently, the stable releases perl 5.14.0-1,
5.12.0-4, 5.10.0-1, 5.8.0-9, and 5.6.0-2
are supported. To add support for another release, simply send me the
release's F<perlapi.pod> via email or via an RT ticket and I'll add it
in the next release.

Additionally, the development release 5.15.1 is included.
API docs for development may be dropped from the distribution
at any time. The general policy on this is to try
and ship the APIs for the newest development release.

=head1 METHODS

=head2 new

Constructor. Takes the C<perl_version> argument which specifies the
version of the perlapi that you want to use. The version has to be
in the form C<5.008009> to indicate perl 5.8.9. For the initial
releases in a new family (5.10.0, etc), the shortened forms
C<5.010> and C<5.01> can be used.

Special C<perl_version> settings are C<newest> and C<newest_devel>
which correspond to the newest available stable and experimental
perl API versions.

=head2 index

Returns the index of perlapi entries and their documentation as a hash
reference.

=head2 perl_version

Returns the API object's perl version. Possibly normalized to the
floating point form (C<version-E<gt>new($version)-E<gt>numify()>).

=head2 as_yaml_calltips

Dumps the index as a YAML file in the format used by the Padre calltips.
Requires L<YAML::Tiny>.

=head1 SEE ALSO

L<perlapi>

L<Perl::APIReference::Generator>

L<Padre>

=head1 AUTHOR

Steffen Mueller, E<lt>smueller@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009, 2010, 2011 by Steffen Mueller

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.6.0 or,
at your option, any later version of Perl 5 you may have available.

=cut
