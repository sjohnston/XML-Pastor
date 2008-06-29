use utf8;
use strict;
use warnings;
no warnings qw(uninitialized);

require 5.008;

use XML::Pastor::Builtin;
use XML::Pastor::ComplexType;
use XML::Pastor::Element;
use XML::Pastor::Generator;
use XML::Pastor::NodeArray;
use XML::Pastor::Schema;
use XML::Pastor::SimpleType;
use XML::Pastor::Stack;
use XML::Pastor::Util;

package XML::Pastor;

use vars qw($VERSION);
$VERSION	= '0.51';

#------------------------------------------------------------
sub new {
	my $proto 	= shift;
	my $class	= ref($proto) || $proto;
	my $self = {@_};	
	return bless $self, $class;
}

#--------------------------------------------------------
sub generate {
	my $self 	= shift;
	my $args	= {@_};
	my $verbose	= $args->{verbose} || $self->{verbose} || 0;
	
	my $parser	=XML::Pastor::Schema::Parser->new(verbose => $verbose);
	my $model 	= $parser->parse(@_, verbose=>$verbose);
	
	print STDERR "\n========= AFTER PARSE =============\n". $model->dump() . "\n\n" if ($verbose >= 8); 	
	
	$model->resolve(@_, verbose=>$verbose);
	print STDERR "\n========= AFTER RESOLVE =============\n". $model->dump() . "\n\n" 	if ($verbose >= 8);
	
	my $generator = XML::Pastor::Generator->new(verbose=>$verbose);
	my $result = $generator->generate(@_, model=>$model, verbose=>$verbose);
	
	print STDERR "\n========= AFTER GENERATE =============\n". $model->dump() . "\n\n" if ($verbose >= 8);
	
	return $result;
}

1;

__END__


=head1 NAME

B<XML::Pastor> - Generate Perl classes with XML bindings starting from a W3C XSD Schema

=head1 SYNOPSIS 

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


  # Generate a SINGLE module which contains all the classes and put it under destination.    
  # Note that the schema may be read from a URL too.
  
  $pastor->generate(	
  			mode =>'offline',
  			style => 'single',
			schema=>'http://some/url/to/schema.xsd', 
			class_prefix=>'MyApp::Data::',
			module => 'Module',
			destination=>'/tmp/lib/perl/', 							
			);  


  # Generate classes in MEMORY, and EVALUATE the generated code on the fly.
  # (Run Time code generation)
  
    $pastor->generate(	
    		mode =>'eval',
			schema=>'/some/path/to/schema.xsd', 
			class_prefix=>'MyApp::Data::'
			);  
  

  # Same thing, with a maximum of DEBUG output on STDERR
 
    $pastor->generate(	
    		mode =>'eval',
			schema=>'/some/path/to/schema.xsd', 
			class_prefix=>'MyApp::Data::',
			verbose = 9
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

Java had CASTOR, and now Perl has B<XML::Pastor>! 

If you know what Castor does in the Java world, then B<XML::Pastor> should be familiar to you. If you have a B<W3C XSD schema>, 
you can generate Perl classes with roundtrip XML bindings.

Whereas Castor is limited to offline code generation, B<XML::Pastor> is able to generate Perl classes 
either offline or at run-time starting from a W3C XSD Schema. The generated classes correspond to 
the global elements, complex and simple type declarations in the schema. The generated classes have full XML binding, 
meaning objects belonging to them can be read from and written to XML. Accessor methods for attributes and child elements will be generated automatically.
Furthermore it is possible to validate the objects of generated classes against the original schema although the schema is typically no longer accessible.

B<XML::Pastor> defines just one method, 'I<generate()>', but the classes it generates define many methods which may
be found in the documentation of L<XML::Pastor::ComplexType> and L<XML::Pastor::SimpleType> from which all generated classes
descend.

In 'I<offline>'  mode, it is possible to generate a single module with all the generated clasess or multiple modules
one for each class. The typical use of the offline mode is during a 'make' process, where you have a set of XSD schemas and you
generate your modules to be later installed by the 'make install'. This is very similar to Java Castor's behaviour. 
This way your XSD schemas don't have to be accessible during run-time and you don't have a performance penalty.

Perl philosophy dictates however, that There Is More Than One Way To Do It. In 'I<eval>' (run-time) mode, the XSD schema is processed at 
run-time giving much more flexibility to the user. This added flexibility has a price on the other hand, namely a performance penalty and 
the fact that the XSD schema needs to be accessible at run-time. Note that the performance penalty applies only to the code genereration (pastorize) phase; 
the generated classes perform the same as if they were generated offline.


=head1 METHODS

=head2 new()       (CONSTRUCTOR)

The new() constructor method instantiates a new B<XML::Pastor> object.  

    my $pastor = XML::Pastor->new();

This is currently unnecessary as the only method ('I<generate>') is a class method. 
However, it is higly recommended to use it and call 'generate' on an object (rather than
the class) as in the future, 'generate' may no longer be a class method.



=head2 generate(%options)         

Currently a B<CLASS METHOD>, but may change to be an B<OBJECT METHOD> in the future. It works when called
on an OBJECT too at this time.

This method is the heart of the module. It will accept a schema file name or URL as input 
(among some other parameters) and proceed to code generation. 

This method will parse the schema(s) given by the L</schema> parameter and then proceed to code generation.
The generated code will be written to disk (mode=>L</offline>) or evaluated at run-time (mode=>L</eval>) depending on the value of the 
L</mode> parameter. 

In L</offline> mode, the generated classes will either all be put in one L</single> big code block, or 
in L</multiple> module files (one for each class) depending on the L</style> parameter. Again in L</offline> mode, the 
generated modules will be written to disk under the directory prefix given by the L</destination> parameter.

In any case, the names of the generated classes will be prefixed by the string given by the L</class_prefix> parameter. 
It is possible to indicate common ancestors for generated classes via the L</complex_isa> and L</simple_isa> parameters.

This metod expects the following parameters: 

=over 

=item schema

This is the file name or the URL to the B<W3C XSD schema> file to be processed. Experimentally, it can also be a string
containing schema XSD. 

Be careful about the paths that are mentioned for any included schemas though. If these are relative, they
will be taken realtive to the current schema being processed. In the case of a schema string, the resolution
of relative paths for the included schemas is undefined.

Currently, it is also possible to pass an array reference to this parameter, in which case the schemas will be processed in order
and merged to the same model for code generation. Just make sure you don't have name collisions in the schemas though.

=item mode

This parameter effects what actuallly will be done by the method. Either offline code generation, or run-time
code evaluation, or just returning the generated code.

=over

=item offline

B<Default>.

In this mode, the code generation is done 'offline', that is, similar to Java's Castor way of doing things, the generated code 
will be written to disk on module files under the path given by the L</destination> parameter.

In 'I<offline>'  mode, it is possible to generate a single module with all the generated clasess or multiple modules
one for each class, depending on the value of the L</style> parameter. 

The typical use of the I<offline> mode is during a 'B<make>' process, where you have a set of XSD schemas and you
generate your modules to be later installed by 'B<make install>'. This is very similar to Java Castor's behaviour. 
This way your XSD schemas don't have to be accessible during run-time and you don't have a performance penalty.

  # Generate MULTIPLE modules, one module for each class, and put them under destination.  
  my $pastor = XML::Pastor->new();	  
  $pastor->generate(	
  			mode =>'offline',
  			style => 'multiple',
			schema=>'/some/path/to/schema.xsd', 
			class_prefix=>'MyApp::Data::',
			destination=>'/tmp/lib/perl/', 							
			);  

=item eval 

In 'I<eval>' (run-time) mode, the XSD schema is processed at 
run-time giving much more flexibility to the user. In this mode, no code will be written to disk. Instead, the generated code 
(which is necessarily a L</single> block) will be evaluated before returning to the caller. 

The added flexibility has a price on the other hand, namely a performance penalty and 
the fact that the XSD schema needs to be accessible at run-time. Note that the performance penalty applies only to the code genereration (pastorize) phase; 
the generated classes perform the same as if they were generated offline.

Note that 'I<eval>' mode forces the L</style> parameter to have a value of 'I<single>';

  # Generate classes in MEMORY, and EVALUATE the generated code on the fly.  
  my $pastor = XML::Pastor->new();	    
  $pastor->generate(	
    		mode =>'eval',
			schema=>'/some/path/to/schema.xsd', 
			class_prefix=>'MyApp::Data::'
			);  

=item return 

In 'I<return>'  mode, the XSD schema is processed but no code is written to disk or evaluated. In this mode, the method
just returns the generated block of code as a string, so that you may use it to your liking. You would typically be evaluating 
it though.

Note that 'I<return>' mode forces the L</style> parameter to have a value of 'I<single>';

=back

=item style

This parameter determines if B<XML::Pastor> will generate a single module where all classes reside (L</single>), or 
multiple modules one for each class (L</multiple>).

Some modes (such as L</eval> and L</return>)force the style argument to be 'I<single>'.

Possible values are :

=over 

=item single 

One block of code containg all the generated classes will be produced. 

=item multiple 

A separate piece of code for each class will be produced. 

=back

=item class_prefix

If present, the names of the generated classes will be prefixed by this value. 
You may end the value with '::' or not, it's up to you. It will be autocompleted. 
In other words both 'MyApp::Data' and 'MyApp::Data::' are valid. 

=item destination

This is the directory prefix where the produced modules will be written in I<offline> mode. In other modes (I<eval> and I<return>), it is ignored.

Note that the trailing slash ('/') is optional. The default value for this parameter is '/tmp/lib/perl/'.

=item module

This parameter has sense only when generating one big chunk of code (L</style> => L</single>) in offline L</mode>. 

It denotes the name of the module (without the .pm extension) that will be written to disk in this case. 

=item complex_isa

Via this parameter, it is possible to indicate a common ancestor (or ancestors) of all complex types that are generated by B<XML::Pastor>.
The generated complex types will still have B<XML::Pastor::ComplexType> as their last ancestor in their @ISA, but they will also have the class whose  
name is given by this parameter as their first ancestor. Handy if you would like to add common behaviour to all your generated classes. 

This parameter can have a string value (the usual case) or an array reference to strings. In the array case, each item is added to the @ISA array (in that order) 
of the generated classes.

=item simple_isa

Via this parameter, it is possible to indicate a common ancestor (or ancestors) of all simple types that are generated by B<XML::Pastor>.
The generated simple types will still have B<XML::Pastor::SimpleType> as their last ancestor in their @ISA, but they will also have the class whose  
name is given by this parameter as their first ancestor. Handy if you would like to add common behaviour to all your generated classes. 

This parameter can have a string value (the usual case) or an array reference to strings. In the array case, each item is added to the @ISA array (in that order) 
of the generated classes.


=item verbose

This parameter indicates the desired level of verbosity of the output. A value of zero (0), which is the default, indicates 'silent' operation where only a fatal
error will result in a 'die' which will in turn write on STDERR. A higher value of 'verbose' indicates more and more chatter on STDERR.


=back

=head1 SCHEMA SUPPORT

The version 1.0 of W3C XSD schema (2001) is supported almost in full, albeit with some exceptions (see L</"BUGS & CAVEATS">). 
Such things as complex and simple types, global elements, groups, attributes, and attribute groups are supported. Type declarations
can either be global or done locally. Complex type derivation by extension and simple type derivation by restriction is supported. All the basic W3C builtin types are supported. Unions and lists are supported. 
Most of the restriction facets for simple types are supported (I<length, minLength, maxLength, pattern, enumeration, minInclusive, maxInclusive, minExclusive, maxExclusive, totalDigits, fractionDigits>). 

Schema inclusion (include) and redefinition (redefine) are supported, allthough for 'redefine' not much testing was done. 

Namespaces are supported in as much as there is no more than one namespace for a given schema. 'Import' is not supported because of this.
 
Neither elements with 'mixed' content nor substitution groups are supported at this time.

=head1 HOW IT WORKS

The source code of the L</generate()> method looks like this:

  sub generate {
	my $self 	= shift;
	
	my $parser	=XML::Pastor::Schema::Parser->new();
	my $model 	= $parser->parse(@_);
	
	$model->resolve(@_);
	
	my $generator = XML::Pastor::Generator->new();
	
	my $result = $generator->generate(@_, model=>$model);		
	
	return $result;
  }


At code generation time, B<XML::Pastor> will first parse the schema(s) into a schema model (XML::Pastor::Schema::Model). The model contains
all the schema information in perl data structures. All the global elements, types, attributes, groups, and attribute groups are put into this
model.

Then, the model is 'resolved', i.e. the references ('ref') are resolved, class names are determined and so on. Then, comes the code generation 
stage where your classes are generated according to the given options. In offline mode, this phase
will write out the generated code onto modules on disk. Otherwise it can also 'eval' the generated code for you. 

The generated classes will contain class data named 'B<XmlSchemaType>' (thanks to L<Class::Data::Inheritable>), which will contain all the schema model 
information that corresponds to this type. For a complex type, it will contain information about child elements and attributes. For a simple type it will 
contain the restriction facets that may exist and so on. 

For complex types, the generated classes will also have accessors for the attributes  
and child elements of that type (thanks to L<Class::Accessor>). However, you can also use direct hash
access as the objects are just blessed hash references. The fields in the has correspond to attributes and
child elements of the complex type. You can also store additional non-XML data in these objects. Such fields 
are silently ignored during validation and XML serialization. This way, your objects can have state information 
that is not stored in XML. Just make sure the names of these fields do not coincide with XML attributes and child 
elements though.

The inheritance of classes are also managed by B<XML::Pastor> for you. Complex types that are derived by extension will automatically be a descendant of the base class. Same applies to the simple types derived by restriction. 
Global elements will always be a descendant of some type, which may sometimes be implicitely defined. Global elements will have an added ancestor L<XML::Pastor::Element> and will also contain an extra class 
data accessor "B<XmlSchemaElement>" which will contain schema information about the model. This class data is currently used mainly to get at the name of the element when
an object of this class is stored in XML (as ComplexTypes don't have an element name). 

Then you I<use> the generated modules. If the generation was offline, you actually need a 'use' statement. If it was an 'eval', you can start
using your generated classes immediately. At this time, you can call many methods on the generated classes that enable you to create, retrieve and save an object from/to XML. There are also
methods that enable you to validate these objects against schema information. Furthermore, you can call the accessors that were automagically 
created for you on class generation for getting at the fields of complex objects. 
Since all the schema information is saved as class data, the schema is no longer needed at run-time.


=head1 NAMING CONVENTIONS FOR GENERATED CLASSES 

The generated classes will all be prefixed by the string given by the L</class_prefix> parameter. The rest of this section
assumes that L</class_prefix> is "B<MyApp::Data>".

Classes that correspond to global elements will keep the name of the element. For example, if there is an element called
'B<country>' in the schema, the corresponding clas will have the name 'B<MyApp::Data::country>'. Note that no change in case occurs. 

Classes that correspond to global complex and simple types will be put under the 'B<Type>' subtree. For example, if there is a complex
type called 'B<City>' in the XSD schema, the corresponding class will be called 'B<MyApp::Data::Type::City>'. Note that no change in case occurs. 

Implicit types (that is, types that are defined I<inline> in the schema) will have auto-generated names within the 'Type' subtree. For example, 
if the 'B<population>' element within 'B<City>' is defined by an implicit type,  its corresponding class will be 'B<MyApp::Data::Type::City_population>'. 

Sometimes implicit types need more to disambiguate their names. In that case, an auto-incremented sequence is used to generate the class names. 

In any case, do not count on the names of the classes for implicit types. The naming convention for those may change. In other words, do not reference
these classes by their names in your program. You have been warned. 


=head1 SUGGESTED NAMING CONVENTIONS FOR XML TYPES, ELEMENTS AND ATTRIBUTES IN W3C SCHEMAS 

Sometimes you will be forced to use a W3C schema defined by someone else. In that case, you will not have a choice for the names of types, elements, and attributes defined in the schema.

But most often, you will be the one who defines the W3C schema itself. So you will have full power over the names within. 

As mentioned earlier, B<XML::Pastor> will generate accesor methods for the child elements and attributes of each class. 
Since there exist some utility methods defined under L<XML::Pastor::ComplexType> and L<XML::Pastor::SimpleType> that are the ancestors of all the generated classes from your schema there is a risk of name collisions. 
Below is a list of suggestions that will ensure that there are no name collisions within your schema and with the defined methods.

=over 

=item Avoid child Elements and attributes with the same name

Never use the same name for an attribute and a child element of the same complex type or element within your schema. For instance, if you have an attribute called 'title' within a Complex type called 'Person', do not 
in any circumstance create a child element with the same name 'title'. Although this is technically possible under W3C schema, XML::Pastor will be confused in this case. The hash field of an object will contain one or the 
other (not both). The behavior of the accessor 'title' will be undefined in this case. Please do not count on any behavior that may exist currently on this subjet as it may change at any time.

=item Element and attribute names should start with lower case

Element ant attribute names (incuding global ones) should start with lower case and be uppercased at word boundries. Example : "firstName", "lastName". Do not use underscore to separate words as this may open up a possibility for 
name collisions of accessors with the names of utility methods defined under L<XML::Pastor::ComplexType> and L<XML::Pastor::SimpleType>.

=item Element and attribute names should not coincide with builtin method names of L<XML::Pastor::ComplexType>

Element ant attribute names (incuding global ones) should not coincide with builtin method names defined under L<XML::Pastor::ComplexType> as this will cause a name collision with the generated accessor method. Extra care should
be taken for the methods called 'B<get>', 'B<set>', and 'B<grab>' as these are one-word builtin method names. Same goes for 'B<isa>' and 'B<can>' that come from Perl's B<UNIVERSAL> package. Multiple word method names should not 
normally cause trouble if you abide by the principle of not using underscore for separating 
words in element and attribute names. See L<XML::Pastor::ComplexType> for the names of other builtin methods for the generated classes.

=item Global complex and simple types should start with upper case

The names of global types (complex and simple) should start with an upper case and continue with lower case. Word boundries should be uppercased. This resembles the package name convention in Perl. 
Example : 'B<City>', 'B<Country>', 'B<CountryCode>'. 

=back

You are free to name global groups and attribute groups to your liking. 


=head1 BUGS & CAVEATS

There no known bugs at this time, but this doesn't mean there are aren't any. 
Note that, although some testing was done prior to releasing the module, this should still be considered alpha code. 
So use it at your own risk.

There are known limitations however:

=over 

=item * Namespaces

The namespace support is somewhat shaky. Currently at most one I<targetNamspace> is supported. 
Multiple target namespaces are not supported. That's why schema 'import' facility does not work. 

=item * Schema import

The 'import' element of W3C XSD schema is not supported at this time. This is basically because of namespace complexities. If you think of a 
way to support the 'import' feature, please let me know. 

=item * 'mixed' elements

Elements with 'mixed' content (text and child elements) are not supported at this time.

=item * substitution groups

Substitution groups are not supported at this time.

=item * Encoding

Only the B<UTF-8> encoding is supported. You should make sure that your data is in UTF-8 format. It may be possible to read (but not write) XML from other encodings. 
But this feature is not tested at this time. 

=item * Default values for attributes

Default values for attributes are not supported at this time. If you can think of a simple way to support this, please let me know.

=back

Note that there may be other bugs or limitations that the author is not aware of.

=head1 AUTHOR

Ayhan Ulusoy <dev@ulusoy.name>


=head1 COPYRIGHT

  Copyright (C) 2006-2008 Ayhan Ulusoy. All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 DISCLAIMER

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, 
THERE IS NO WARRANTY FOR THE SOFTWARE, 
TO THE EXTENT PERMITTED BY APPLICABLE LAW. 
EXCEPT WHEN OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES PROVIDE 
THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, 
EITHER EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, 
THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. 
THE ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH YOU. 
SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING 
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR REDISTRIBUTE THE SOFTWARE 
AS PERMITTED BY THE ABOVE LICENCE, BE LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, 
SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE THE SOFTWARE 
(INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING RENDERED INACCURATE OR LOSSES SUSTAINED BY 
YOU OR THIRD PARTIES OR A FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), 
EVEN IF SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.


=head1 SEE ALSO

See also L<XML::Pastor::ComplexType>, L<XML::Pastor::SimpleType>

If you are curious about the implementation, see also L<XML::Pastor::Schema::Parser>, L<XML::Pastor::Schema::Model>, L<XML::Pastor::Generator>.

=cut

1;


