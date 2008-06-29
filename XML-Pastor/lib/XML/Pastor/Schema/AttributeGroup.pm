use utf8;
use strict;

use XML::Pastor::Schema::Object;

package XML::Pastor::Schema::AttributeGroup;
our @ISA = qw(XML::Pastor::Schema::Object);

XML::Pastor::Schema::AttributeGroup->mk_accessors(qw(attributes attributeInfo));

sub new {
	my $proto 	= shift;
	my $class	= ref($proto) || $proto;
	my $self = {@_};
	
	unless ($self->{attributes}) {
		$self->{attributes} = [];
	}
	unless ($self->{attributeInfo}) {
		$self->{attributeInfo} = {};
	}
	unless ($self->{contentType}) {
		$self->{contentType} = "attributeGroup";
	}
	
	return bless $self, $class;
}

1;

__END__

=head1 NAME

B<XML::Pastor::Schema::AttributeGroup> - Class that represents the META information about a W3C schema B<attribute group>.

=head1 WARNING

This module is used internally by L<XML::Pastor>. You do not normally know much about this module to actually use L<XML::Pastor>.  It is 
documented here for completeness and for L<XML::Pastor> developers. Do not count on the interface of this module. It may change in 
any of the subsequent releases. You have been warned. 

=head1 ISA

This class descends from L<XML::Pastor::Schema::Object>.


=head1 SYNOPSIS
  
  my $ag = XML::Pastor::Schema::AttributeGroup->new();
  
  $ag->setFields(name => 'personal', scope=> 'global', nameIsAutoGenerated=>0);

  $ag->attributes(['lastName', 'firstName', 'title', 'dateOfBirth']);
  
  print $ag->name();	# prints 'personal'.
  print $ag->scope();	# prints 'global'.
  

=head1 DESCRIPTION

B<XML::Pastor::Schema::AttributeGroup> is a data-oriented object class that reprsents a W3C B<attribute group>. It is
parsed from the W3C schema and is used a building block for the produced B<schema model>. Objects of this 
class contain META information about the W3C schema B<attribute group> that they represent. 

Like other schema object classes, this is a data-oriented object class, meaning it doesn't have many methods other 
than a constructor and various accessors. 

=head1 METHODS

=head2 CONSTRUCTORS
 
=head4 new() 

  $class->new(%fields)

B<CONSTRUCTOR>, overriden. 

The new() constructor method instantiates a new B<XML::Pastor::Schema::Object> object. It is inheritable, and indeed inherited,
by the decsendant classes. 
  
Any -named- fields that are passed as parameters are initialized to those values within
the newly created object. 

In its overriden form, what this method does is as follows:

=over

=item * sets the I<contentType> field to 'I<attributeGroup>';

=item * creates the B<attributes> array-ref field if not passed already as a parameter;

=item * creates the B<attributeInfo> hash-ref field if not passed already as a parameter;

=back

.

=head2 ACCESSORS

=head3 Inherited accessors

Several accessors are inherited by this class from its ancestor L<XML::Pastor::Schema::Object>. 
Please see L<XML::Pastor::Schema::Object> for a documentation of those.

=head3 Accessors defined here

=head4 attributes()

  my $attribs = $object->attributes();  # GET
  $object->attributes($attribs);        # SET

A reference to an array containing the names of the attributes that this B<attribute group> has.

=head4 attributeInfo()

  my $ai = $object->attributeInfo();  # GET
  $object->attributeInfo($ai);        # SET

A reference to a hash whose keys are the names of the attributes, and whose values are
objects of type L<XML::Pastor::Schema::Attribute>, that give meta information about those attributes.


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

See also L<XML::Pastor>, L<XML::Pastor::ComplexType>, L<XML::Pastor::SimpleType>

If you are curious about the implementation, see L<XML::Pastor::Schema::Parser>,
L<XML::Pastor::Schema::Model>, L<XML::Pastor::Generator>.

If you really want to dig in, see L<XML::Pastor::Schema::Attribute>, L<XML::Pastor::Schema::AttributeGroup>,
L<XML::Pastor::Schema::ComplexType>, L<XML::Pastor::Schema::Element>, L<XML::Pastor::Schema::Group>,
L<XML::Pastor::Schema::List>, L<XML::Pastor::Schema::SimpleType>, L<XML::Pastor::Schema::Type>, 
L<XML::Pastor::Schema::Object>

=cut

