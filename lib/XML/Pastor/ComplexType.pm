use utf8;
use strict;

#======================================================
package XML::Pastor::ComplexType;

use XML::LibXML;
use File::Path;
use File::Spec;
use IO::File;
use IO::Handle;
use LWP::UserAgent;
use XML::Pastor::Type;

our @ISA = qw(XML::Pastor::Type);



XML::Pastor::ComplexType->mk_accessors(qw());


1;

__END__

=head1 NAME

B<XML::Pastor::ComplexType> - Ancestor of all complex classes generated by L<XML::Pastor>

=head1 ISA

This class descends from L<XML::Pastor::Type>. 
All your generated complex classes descend from this class. 

=head1 SYNOPSIS 

First, you need to generate your classes using L<XML::Pastor>. See the documentation of L<XML::Pastor> for more examples of this.
L<XML::Pastor> will then generate classes corresponding to the global elements and type definitions (complex and simple) in your W3C schema.

  use XML::Pastor;
   
  my $pastor = XML::Pastor->new();

  # Generate MULTIPLE modules, one module for each class, and put them under destination.  
	  
  $pastor->generate(	
  			mode =>'offline',
  			style => 'multiple',
			schema=>'/some/path/to/schema.xsd', 
			class_prefix=>'MyApp::Data::',
			destination=>'/tmp/lib/perl/', 							
			);  


  
And somewhere in an other place of the code ...  
(Assuming a global XML element 'country' existed in you schema and hence been generated by Pastor).

  my $country = MyApp::Data::country->from_xml_file('/some/path/to/country.xml');    # retrieve from a file    
  $country = MyApp::Data::country->from_xml_url('http://some/url/to/country.xml');	 # or from a URL
  $country = MyApp::Data::country->from_xml_fh($fh); 	# or from a file handle  
  $country = MyApp::Data::country->from_xml_dom($dom);	# or from DOM  (a XML::LibXML::Node or XML::LibXML::Document)

  # or from an XML string
  $country = MyApp::Data::country->from_xml_string(<<'EOF');
  
  <?xml version="1.0"?>
  <country code="FR" name="France">
    <city code="PAR" name="Paris"/>
    <city code="LYO" name="Lyon"/>    
  </country>
  EOF
  
  # or if you don't know if you have a file, URL, FH, or string
  $country = MyApp::Data::country->from_xml('http://some/url/to/country.xml');
  
  
  # Now you can manipulate your country object.  
  print $country->name;					# prints "France"
  print $country->city->[0]->name;		# prints "Paris"
  
  
  # Let's make some changes  
  $country->code('fr');
  $country->name('FRANCE');
  
  my $class=$country->xml_field_class('city');
  my $city = $class->new();
  $city->code('MRS');
  $city->name('Marseille');
  
  push @{$country->city}, $city;
  
  print $country->city->[2]->name;	# prints "Marseille"
  
  # Time to validate our XML
  $country->xml_validate();			# This one will DIE on failure
  
  if ($country->is_xml_valid()) {	# This one will not die.
    print "ok\n";
  }else {
    print "Validation error : $@\n";  # Note that $@ contains the error message
  }  
  
  # Time to write the the object back to XML
  $country->to_xml_file('some/path/to/country.xml');		# To a file  
  $country->to_xml_url('http://some/url/to/country.xml');	# To a URL  
  $country->to_xml_fh($fh);					# To a FILE HANDLE  

  my $dom=$country->to_xml_dom();			# To a DOM Node (XML::LibXML::Node)
  my $dom=$country->to_xml_dom_document();	# To a DOM Document  (XML::LibXML::Document)
  my $xml=$country->to_xml_string();		# To a string  
  my $frag=$country->to_xml_fragment();		# Same thing without the <?xml version="1.0?> part
    
 
=head1 DESCRIPTION

B<XML::Pastor::ComplexType> is an B<abstract> ancestor of all complex classes (including those corresponding to global elements) generated 
by L<XML::Pastor> which is a Perl code generator from W3C XSD schemas. For an introduction, please refer to the
documentation of L<XML::Pastor>.

B<XML::Pastor::ComplexType> defines several methods that serve mainly to achieve the XML binding of generated classes that inherit from it.
Yet, this class remains abstract because it is void of meta information related to the W3C schema that is defined for each generated class.

In fact, B<XML::Pastor::ComplexType> contains (actually I<inherits from> L<XML::Pastor::Type>) a class data accessor called L</XmlSchemaType()> with the help of L<Class::Data::Inheritable>. This
accessor is normally used by many other methods to access the W3C schema meta information related to the class at hand. But at this stage, L</XmlSchemaType()>
does not contain any information and this is why B<XML::Pastor::ComplexType> remains abstract. 

The generated subclasses set L</XmlSchemaType()> to information specific to the W3C schema type. It is then used for the XML binding and validation methods. 

The generated classes also automatically define accessor methods for the attributes and child elements of the complex type (or element) at hand. 
(See L<ACCESSORS> for more information).

Notice that you can set any other field in the object that can be used as a hash key. It doesn't have to 
be a valid XML attribute or child element. You may then access the same field using the usual hash access. 
You can use this feature to save state information that will not be written back to XML. Just make sure that
the names of any such fields do not coincide with the name of an actual attribute or child element. Any such field will be 
silently ignored when writing to or validating XML. However, note that there won't be any auto-generated 
accessor for such fields. But you can actually achieve this by using the
B<mk_accessors> method from L<Class::Accessor> somewhere else in your code as B<XML::ComplexType> eventually 
inherits from L<Class::Accessor>.

Generated classes for simple types do not descend from this class. Instead, they descend from L<XML::Pastor::SimpleType> (although both have a common ancestor 
called L<XML::Pastor::Type>).
  
.

=head1 METHODS

B<WARNING 1> : Normally, you never call the methods defined by B<XML::Pastor::ComplexType> on this class itself. Instead,
you call them on your descendant generated classes which inherit all these methods.

B<WARNING 2> : You should not use the names of these methods for the attributes and child elements within
your W3C schemas. If you do, the behavior is undefined! You have been warned! If you follow the naming 
conventions given by L<XML::Pastor>, you should be OK in any case. 
See L<XML::Pastor/SUGGESTED NAMING CONVENTIONS FOR XML TYPES, ELEMENTS AND ATTRIBUTES IN W3C SCHEMAS> for more info.

.


=head2 ACCESSORS

B<XML::Pastor::ComplexType> does not define accessors on itself, but the generated classes
that correspond to complex types and global elements will have accessors defined for their B<attributes> and 
B<child elements>. This is done via L<Class::Accessor>.

The accessors will be in the usual Perl form, meaning the name of the accessor will be the same of
the B<attribute> or B<child element>. When called without any arguments, the accessor serves as a GETTER, 
and when called with a single argument it serves as a SETTER.

For attributes and B<singleton> child elements with simple content, the accesors (GET) will return an object of a class 
that descends eventually from L<XML::Pastor::SimpleType>. This may be a builtin class defined by L<XML::Pastor::Builtin> or
a generated class that derives from one if you have defined the type in your B<W3C schema>. 
When setting a value of an attribute or a child element with simple content, you can either use an object of that same
class or otherwise you can just use a SCALAR or a completely different object that stringifies to the desired value. 
But be warned that the accessor does not change your SCALAR or object into an object of correct class. B<XML::Pastor> is 
just clever enough to convert those into the desired class on the fly upon validation or storage.  

A child element that is a B<singleton> (i.e., the B<maxOccurs> schema property is undefined or '1'), its accessor will return an object
of a class that eventually descends from B<XML::Pastor::ComplexType>. This will typically be a generated class that derives from
your B<W3C schema>. When setting the value of such a child element, you should use an object of that same class (or one that derives 
from it). In fact, currently, you may also use a plain hash but this is an experimental feature so don't count on it to work.

For a child element that is B<not> a B<singleton> (i.e. the B<maxOccurs> schema property is greater than '1' or is 'B<unbounded>'), the
accessor will return a L<XML::Pastor::NodeArray> object (which is just a blessed array with some overloading functionality) that will 
contain one item for each child element with the same name in the order that they appear in the XML. Each item will be an object of a 
class that descends eventually from B<XML::Pastor::ComplexType> or L<XML::Pastor::SimpleType> depending on whether the element has simple
or complex content. When setting the value of such a child element with B<multiplicity>, you will have great freedom. The preffered way is
to use a L<XML::Pastor::NodeArray> object just as it is returned by the accessor (GETTER). But you don't have to. You can use a plain array
instead. Currently, you can even use a single object (without an array) if you know that you will only put one element in there. But this is 
not such a good way of doing things. Besides, this feature is experimental so it may go away in the future. So try to stick with at least a plain
array and you should be fine. The items in the array can even be plain scalars if the child element has simple content (see above for the attribute case). 


.


=head2 OTHER METHODS


.


=head4 is_xml_valid()

  $bool = $object->is_xml_valid();

B<OBJECT METHOD>, inherited from L<XML::Pastor::Type>. Documented here for completeness.

'B<is_xml_valid>' is similar to L</xml_validate> except that it will not B<die> on failure. 
Instead, it will just return FALSE (0). 

The implementation of this method, inherited from L<XML::Pastor::Type>, is very simple. Currently,
it just calls L</xml_validate> in an B<eval> block and will return FALSE (0) if L</xml_validate> dies.  
Otherwise, it will just return the same value as L</xml_validate>.

In case of failure, the contents of the special variable C<$@> will be left untouched in case you would like to access the 
error message that resulted from the death of L</xml_validate>.

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

See also  L<XML::Pastor::Type>, L<XML::Pastor::SimpleType>, L<XML::Pastor>

And if you are more curious, see L<XML::Pastor::Type> (the ancestor of this class), 
L<XML::Pastor::Schema::ComplexType> (meta type information from your B<W3C schema>)

And if you are even more curious, see L<Class::Accessor>, L<Class::Data::Inheritable>


=cut

