# $Id$
#
use strict;
use warnings;
use utf8;

package XML::Pastor::NodeArray;
require 5.008;

use Carp qw(carp cluck);
use Data::Dumper;
use Scalar::Util qw(reftype);

use vars qw($VERSION);
$VERSION = '0.18';

our $AUTOLOAD;

# Hash deref. gives access to the first element
# For debugging purpose only
#carp "\033\[0;35m[NOTICE] Overloaded '\"\"' called (".
#  __PACKAGE__.")\033\[0m";
use overload (
    '%{}'      => sub { $_[0]->_hash_access; },
    '""'       => sub { "". $_[0]->_hash_access; },
    'fallback' => 1,
);

# --------------------------------------------------------------------
# Constructor
# --------------------------------------------------------------------

sub new {
    my ($proto, @array) = @_;
    my $class = ref($proto) || $proto;

    bless \@array, $class;
}


# Return the first element (which is normally a hash ref) of the list
sub _hash_access () {
    my ($self) = @_;

    my $item = eval { $self->[0]; };
    if ($@) {
        cluck "$@";
    }

    #carp "Hash-access => DONE\n";
    return $item;
}

#-------------------------------------------------------
# hash(field1, field2, field3, ...)
#
# Return a hash keyed on field1. If there is no field2, this will be 
# a hash of NodeArrays. If field2 exists, this will be a hash of hashes of
# NodeArrays. And so on...
# 
# Breadth-first recursive.
#-------------------------------------------------------
sub hash {
	my $self	= shift;
	my $class	= ref($self);	
	return undef unless (@_);	
	my $field	= shift;
	return undef unless defined($field);
		
	my $h = {};
	
	# Hash the array on '$field';
	foreach my $item (@$self) {
		my $key = $item->{$field};
		
		# If the keyed item doesn't yet exist, create a new NodeArray and assign it.
		unless ( exists($h->{$key}) ) {
			$h->{$key} = $class->new();
		}
		
		# Push the item on the keyed NodeArray.
		my $array= $h->{$key};		
		push @$array, $item;
	}

	# If we don't have any more fields, just return the hash.
	return $h unless (@_);

	# Otherwise, further hash each item in the hash on the remaining fields.
	foreach my $key (keys %$h) {
		my $array = $h->{$key};
		$h->{$key} = $array->hash(@_);
	}
	return $h;	
}


#-------------------------------------------------------
# By default, all method calls are delegated to the first element.
#-------------------------------------------------------
sub AUTOLOAD {
    my $self = shift;
    my $func = $AUTOLOAD;
    $func    =~ s/.*:://;

    if ($func =~ /^[0-9]+$/o) {
        return eval { $self->[$func]; };
    }

    return undef if $func eq 'DESTROY';
    if (reftype($self) && reftype($self) eq 'ARRAY') {
        $self->_hash_access->$func(@_);
    } else {
        cluck "*** \$self->$func";
    }
}


1;


__END__


=head1 NAME

B<XML::Pastor::NodeArray> - An array class of hashes that has magical properties via overloading and AUTOLOAD. 

=head1 ISA

This class does not descend from any other class. 

=head1 SYNOPSIS

  my $a = XML::Pastor::NodeArray->new(
					  {code=>'FR', name=>'France', size=>'medium'},
					  {code=>'TR', name=>'Turkey', size=>'medium'},
					  {code=>'US', name=>'United States', size=>'large'}
					  );

  print $a->[2]->{name};    # Prints 'United States'. No surprise.
  print $a->[0]->{name};    # Prints 'France'. No surprise.
  print $a->{name};	        # Prints 'France'. OVERLOADED hash access.

  my $h = $a->hash{'code'};  		# One level hash (returns a hash of a NodeArray of hashes)
  my $h = $a->hash{'size', 'code'};	# Two level hash (returns a hash of a hash of a NodeArray  of hashes)
  

=head1 DESCRIPTION

B<XML::Pastor::NodeArray> is an array class that is used for element multiplicity in L<XML::Pastor>. 

Normally, B<XML::Pastor::NodeArray> is an array of hashes or hash-based objects. This class has some magical properties
that make it easier to deal with multiplicity. 

First, there exist two B<overload>s. One for hash access and the other for stringification. Both will act on the first 
element of the array. In other words, performing a hash access on an object of this class will be equivalent to 
performing a hash access on the first element of the array. 

Second, the AUTOLOAD method will delegate any method unkown to this class to the first item in the array as well. For this to 
work, at least the first item of the array better be an object on which one could call such a method. 

Both of these magical properties make it easier to deal with unpredictable multiplicity. You can both treat the object as an array 
or as hash (the first one in the array). This way, if your code deosn't know that an element can occur multiple times (in other words, if the
code treats the element as singular), the same code should still largely work when the singualr element is replaced by a B<XML::Pastor::NodeARray> object. 

The other practical feature of this class is the capabality to place the objects (or hashes) in the array into a hash keyed on the value of a given field or fields 
(see the L</hash()> method for further details).

=head1 OVERLOADS

Two overloads are performed so that a B<XML::Pastor::NodeArray> object looks like a simple hash or a singular object if treated like one.

=head4 hash access

If an object of this class is accessed as if it were a reference to a hash with the usual C<$object-E<gt>{$key}> syntax, it will I<behave> just like 
a genuine hash. The access will be made on the first item of the array (as this is an array class) assuming this item is a hash or hash-based object. 

=head4 stringification

If an object of this class is accessed as if it were a string, then the stringification of the first item of the array will be returned. 


=head1 METHODS

=head2 CONSTRUCTORS
 
=head4 new() 

  my $array = XML::Pastor::NodeArray->new();		# An empty array
  my $array = XML::Pastor::NodeArray->new(@items);	# An array with initial items in it.

B<CONSTRUCTOR>.

The new() constructor method instantiates a new B<XML::Pastor::NodeArray> object. 
This method is inheritable.
  
Any items that are passed in the parameter list will form the initial items of the array. 


=head2 OTHER METHODS

=head4 hash()

  my $h = $array->hash($field);		# Single hash level with one key field
  my $h = $array->hash(@fields);	# Multiple hash levels with several key fields

B<OBJECT METHOD>.

Remember that the items of a B<XML::Pastor::NodeArray> object are supposed to be hashes or at least
hash-based objects. 

When called with a single argument, the B<hash()> method will create a hash of the items of the array 
keyed on the value of the argument 'field'. 

An example is best. Assume that we have a B<XML::Pastor::NodeArray> object that looks like the following :

  my $array = bless ([
                      {code=>'FR', name=>'France', size=>'medium'},
                      {code=>'TR', name=>'Turkey', size=>'medium'},
                      {code=>'US', name=>'United States', size=>'large'}
                     ], 'XML::Pastor::NodeArray');

Now, if we make a call to B<hash()> as follows:

  my $hash = $array->hash('code');
 
Then the resulting hash will look like the following:
  
  $hash = {
           FR=> bless ([{code=>'FR', name=>'France', size=>'medium'], 'XML::Pastor::NodeArray'),
           TR=> bless ([{code=>'TR', name=>'Turkey', size=>'medium'], 'XML::Pastor::NodeArray'),
           US=> bless ([{code=>'US', name=>'United States', size=>'large'}, 'XML::Pastor::NodeArray')
  };
  
When, multiple fields are passes, then multiple levels of hashes will be created each keyed on the
field of the corresponding level. 

If, for example, we had done the following call on the above array:
  my $hash = $array->hash('size', 'code'};
  
We would then get the following hash:

  $hash = {
  	large =>  {
                US=> bless ([{code=>'US', name=>'United States', size=>'large'}, 'XML::Pastor::NodeArray')
                },
   	medium => {
                 FR=> bless ([{code=>'FR', name=>'France', size=>'medium'}], 'XML::Pastor::NodeArray'),
                 TR=> bless ([{code=>'TR', name=>'Turkey', size=>'medium'}], 'XML::Pastor::NodeArray')
                 }
   };

Note that the last level of the hierarachy is always a NodeArray of hashes. This is done to accomodate the case
where more then one item can have the same key.

.

=head1 BUGS & CAVEATS

There no known bugs at this time, but this doesn't mean there are aren't any. 
Note that, although some testing was done prior to releasing the module, this should still be considered alpha code. 
So use it at your own risk.

Note that there may be other bugs or limitations that the author is not aware of.

=head1 AUTHOR

Ayhan Ulusoy <dev@ulusoy.name>


=head1 COPYRIGHT

  Copyright (C) 2006-2007 Ayhan Ulusoy. All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.


=head1 SEE ALSO

See also L<XML::Pastor>, L<XML::Pastor::ComplexType>


=cut
