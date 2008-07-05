use utf8;
use strict;

use XML::LibXML;
use File::Path;
use File::Spec;
use IO::File;
use IO::Handle;
use LWP::UserAgent;
use Scalar::Util;

use XML::Pastor::Type;

package XML::Pastor::ComplexType;
use Scalar::Util qw(reftype);
use XML::Pastor::Util  qw(getAttributeHash getChildrenHashDOM);

our @ISA = qw(XML::Pastor::Type);

XML::Pastor::ComplexType->mk_accessors(qw());


#------------------------------------------------------
# CLASS METHOD
# Return the Perl class name of a given field (element or attribute).
#------------------------------------------------------
sub  xml_field_class($$)  {
	my $self 	= shift;
	my $field	= shift;
	my $class;
	
	my $type		= $self->XmlSchemaType();		
	
	# Try with elements
	my $elementInfo = $type->effectiveElementInfo();	
	if (defined(my $element = $elementInfo->{$field})) {
		$class= $element->class();
	}
	
	# Return the class if we already have it.
	return $class if ($class);

	# Try with attributes	
	my $attribInfo = $type->effectiveAttributeInfo();	
	if (defined(my $attrib = $attribInfo->{$field})) {
		$class= $attrib->class();
	}
	
	return $class;
}

#------------------------------------------------------
# CLASS METHOD
# Return the singletonness of a given field.
#------------------------------------------------------
sub  is_xml_field_singleton($$)  {
	my $self 	= shift;
	my $field	= shift;

	my $type		= $self->XmlSchemaType();		
	
	# Try with elements
	my $elementInfo = $type->effectiveElementInfo();	
	if (defined(my $element = $elementInfo->{$field})) {
		return $element->isSingleton();
	}
		
	# Try with attributes	
	my $attribInfo = $type->effectiveAttributeInfo();	
	if (defined(my $attrib = $attribInfo->{$field})) {
		return 1;	# An attribute is always singleton.
	}

	# unkown
	return undef;
}

#------------------------------------------------------
# CLASS METHOD
# Return the multiplicity of a given field.
#------------------------------------------------------
sub  is_xml_field_multiple($$)  {
	my $self = shift;
	return !$self->is_xml_field_singleton(@_);
}
	
#------------------------------------------------------
# Grab a field. The difference from 'get'is that 'grab' will create
# the field if it doesn't exist (correctly typed).
#------------------------------------------------------
sub  grab($)  {
	my $self 	= shift;
	my $field	= shift;
	
	return $self->{$field} if ( defined($self->{$field}) );	
	return undef unless (UNIVERSAL::can($self, "XmlSchemaType"));
	
	my $type		= $self->XmlSchemaType();		
	
	# Try with elements
	my $elementInfo = $type->effectiveElementInfo();	
	if (defined(my $element = $elementInfo->{$field})) {
		my $class= $element->class();
		if (defined($class)) {
			my $result;			
						
			if ($element->isSingleton()) {
				# singleton
				$result = $self->{$field} = $class->new();
			}else {
				# multiplicity
				
				# What to do? Should we return an empty array or one having an object in it?
				$result = $self->{$field} = XML::Pastor::NodeArray->new();					
#				$result = $self->{$field} = XML::Pastor::NodeArray->new($class->new());	
			}						
			return $result;
		}
	}
	
	# Try with attributes
	my $attribInfo = $type->effectiveAttributeInfo();	
	if (defined(my $attrib = $attribInfo->{$field})) {
		my $class= $attrib->class();
		if (defined($class)) {
			my $result = $self->{$field}=$class->new();
			return $result;
		}
	}
	return undef;		                                                                                                         
}



#-------------------------------------------------------------
# CONSTRUCTOR
# Create a new object and fill its fields from a DOM element.
# Uses heavily the type information in XmlSchemaType.
#--------------------------------------------------------------
sub from_xml_dom($) {
	my $self	= shift;
	my $node	= shift;
	my $verbose	= 0;
	
	# If we have encountered a document, just recurse into the ROOT element.	
	if (UNIVERSAL::isa($node, "XML::LibXML::Document")) {
		return $self->from_xml_dom($node->documentElement());
	}
	
	my $type	= $self->XmlSchemaType();
		
	# This method behaves as a constructor.		
	$self 		= $self->new();	
		
	# This is a secret place where we put the node name in case we need it later.
	# TODO : Namespaces
	$self->{'._nodeName_'} = $node->localName();

	# Get the attributes from DOM into self		
	my $attribs 	= getAttributeHash($node);
	my $attribInfo	= $type->effectiveAttributeInfo();
	my $attribPfx	= $type->attributePrefix() || '';
	
	foreach my $attribName (@{$type->effectiveAttributes()}) {
		next unless ( defined($attribs->{$attribName})); 
		
		my $class = $attribInfo->{$attribName}->class();
		print "\nfrom_xml_dom : Attribute = $attribName,  Class = $class" if ($verbose >= 7);			
		$self->{$attribPfx . $attribName} = $class->new(value => $attribs->{$attribName});
	}

	# Get the child elements from DOM into self			
	my $children 	= getChildrenHashDOM($node);
	my $elemInfo	= $type->effectiveElementInfo();
	
	foreach my $elemName (@{$type->effectiveElements()}) {
		next unless ( defined($children->{$elemName}));
		
		my $elem  		= $elemInfo->{$elemName};
		my $class 		= $elem->class();
		my $childNodes	= $children->{$elemName};
		
		if ($elem->isSingleton()) {
			# singleton
			$self->{$elemName} = $class->from_xml_dom($childNodes->[0]);
		}else {
			# multiplicity
			$self->{$elemName} = XML::Pastor::NodeArray->new(map {$class->from_xml_dom($_)} @$childNodes);				
		}
	}
	return $self;
}


#-------------------------------------------------------------------
# CONSTRUCTOR
# Parse an XML resource (string, file or URL) and return the object that represents it.
#-------------------------------------------------------------------
sub from_xml {
	my $self		= shift;
	my $resource	= shift;
	
SWITCH:	for ($resource) {
	UNIVERSAL::isa($_, "XML::LibXml::Document") and do {return $self->from_xml_dom($resource, @_); };
	UNIVERSAL::isa($_, "XML::LibXml::Element")  and do {return $self->from_xml_dom($resource, @_); };	
	UNIVERSAL::isa($_, "IO::Handle")  			and do {return $self->from_xml_fh($resource, @_); };		
	UNIVERSAL::isa($_, "URI")  					and do {return $self->from_xml_url($resource, @_); };			
	/^(http|https|ftp|file):/i					and do {return $self->from_xml_url($resource, @_); };
	/<\//										and do {return $self->from_xml_string($resource, @_) };
	OTHERWISE:									return $self->from_xml_file($resource, @_); 
	}
}

#-------------------------------------------------------------------
# CONSTRUCTOR
# Parse an XML file and return the object that represents it.
#-------------------------------------------------------------------
sub from_xml_file {
	my $self	= shift;
	my $file	= shift;
	
	return undef unless ($file);
	my $parser 	= XML::LibXML->new();
    my $dom 	= $parser->parse_file($file);
    return $self->from_xml_dom($dom);		
}

#-------------------------------------------------------------------
# CONSTRUCTOR
# Parse an XML file handle and return the object that represents it.
#-------------------------------------------------------------------
sub from_xml_fh {
	my $self	= shift;
	my $fh		= shift;
	
	my $parser 	= XML::LibXML->new();
    my $dom 	= $parser->parse_fh($fh);
    return $self->from_xml_dom($dom);		
}

#-------------------------------------------------------------------
# CONSTRUCTOR
# Parse an XML fragment string and return the object that represents it.
#-------------------------------------------------------------------
sub from_xml_fragment {
	my $self	= shift;
	my $str		= shift;
	
	return undef unless ($str);
    return $self->from_xml_string('<?xml version="1.0"?>' . "\n".$str);		
}

#-------------------------------------------------------------------
# CONSTRUCTOR
# Parse an XML string and return the object that represents it.
#-------------------------------------------------------------------
sub from_xml_string {
	my $self	= shift;
	my $str		= shift;
	
	return undef unless ($str);
	my $parser 	= XML::LibXML->new();
    my $dom 	= $parser->parse_string($str);
    return $self->from_xml_dom($dom);		
}

#-------------------------------------------------------------------
# CONSTRUCTOR
# Parse an XML internet resource and return the object that represents it.
#-------------------------------------------------------------------
sub from_xml_url {
	my $self	= shift;
	my $url	= shift;
	
	return undef unless ($url);	
	
	my $ua = LWP::UserAgent->new;
  	$ua->agent("Pastor/0.1 ");

  	# Create a request
  	my $req = HTTP::Request->new(GET => $url);

	# Pass request to the user agent and get a response back
	my $res = $ua->request($req);

  	# Check the outcome of the response
  	unless ($res->is_success) {
  		die "Pastor: ComplexType : from_xml_url : cannot GET from URL '$url' : " . $res->status_line . "\n";
  	}
  		
    my $str = $res->content;
	my $parser 	= XML::LibXML->new();
    my $dom 	= $parser->parse_string($str);
    return $self->from_xml_dom($dom);		
}


#-------------------------------------------------------------------
# Convert to object to XML and PUT it to the resource that is passed. 
#-------------------------------------------------------------------
sub to_xml {
	my $self		= shift;
	my $resource	= shift;
	
SWITCH:	for ($resource) {
	UNIVERSAL::isa($_, "IO::Handle")  							and do {return $self->to_xml_fh($resource, @_); };			
	UNIVERSAL::isa($_, "URI")  									and do {return $self->to_xml_url($resource, @_); };				
	!defined($resource) ||  (reftype($resource) eq 'SCALAR')	and do {return ($$resource = $self->to_xml_string(@_)); };
	/^(http|https|ftp|file):/i									and do {return $self->to_xml_url($resource, @_); };
	OTHERWISE:													return $self->to_xml_file($resource, @_); 
	}
}

#-------------------------------------------------------------
# Convert the data in this object to a DOM element and return the DOM tree.
# Uses heavily the type information in XmlSchemaType.
#-------------------------------------------------------------
sub to_xml_dom {
	my $self	= shift;
	my $args	= {@_};
	my $doc		= $args->{doc};
	my $name	= $args->{name};
	my $type	= $self->XmlSchemaType();	
	my $node;	
	my $doc_new;
	my $targetNamespace;
	
	unless ( defined($doc) ) {
		$doc = $args->{doc}= XML::LibXML::Document->new();
		$doc_new = 1;
	}
		
	unless ($name) {
		if (UNIVERSAL::can($self, "XmlSchemaElement")) {
			my $xmlSchemaElement = $self->XmlSchemaElement;
			$name = $xmlSchemaElement->name();
		}else {
			$name = $self->{'._nodeName_'};			
		}
	}
	
	# We absolutely need a name
	$name or die "Pastor: to_xml_dom : Element needs a name!\n";

	# Get the target name-space.
	if (UNIVERSAL::can($self, "XmlSchemaElement")) {
		my $xmlSchemaElement = $self->XmlSchemaElement;
		$targetNamespace=$xmlSchemaElement->targetNamespace if  ($xmlSchemaElement->scope =~ /global/i);
	}

	# Create the node		
	if ($targetNamespace) {
		$node=$doc->createElementNS($targetNamespace, $name);		
	}else {
		$node=$doc->createElement($name);
	}
	
	$doc->setDocumentElement($node) if ($doc_new);
	
	# Attributes
	my $attributes	= $type->effectiveAttributes();
	my $attribPfx	= $type->attributePrefix() || '';
	
	foreach my $attribName (@$attributes) {
		my $field = $attribPfx . $attribName;
		my $value = $self->{$field};
		next unless defined($value);
		$node->setAttribute($attribName, "" . $value); # force stringification.				
	}
	
	# Elements
	my $elements	= $type->effectiveElements();
	my $elementInfo	= $type->effectiveElementInfo();	
	foreach my $elemName (@$elements) {
		my $value = $self->{$elemName};
		next unless defined($value);		
		$value = [$value] unless (reftype($value) eq 'ARRAY');
		my $element = $elementInfo->{$elemName};

		foreach my $item (@$value) {
			my $obj = $item;			
			my $class = $element->class;
			if (!UNIVERSAL::can($item, "to_xml_dom")) {
			    if ( (reftype($item) eq 'HASH') && UNIVERSAL::isa($class, "XML::Pastor::ComplexType")){
					# Item should be of ComplexType, but it is just Hash. Fix it and then do the job.	
					$obj = $class->new(%$item);
				}elsif (UNIVERSAL::isa($class, "XML::Pastor::SimpleType")){
					# Item should be of SimpleType. Fix it and then do the job.						
					$obj = $class->new(value => "$item");					
			    }else {
					die "Pastor : to_xml_dom : Don't know how to transform '$elemName' into DOM (not a known or convertable type)";	
				}
			}
			
			if (defined(my $childNode = $self->_childToDom(doc=>$doc, name=>$elemName, child=>$obj))) {
				$node->appendChild($childNode);
			}
			last if ($element->isSingleton());		# singleton
		}								
	}
	
	return $node;
}

#-------------------------------------------------------------
sub to_xml_dom_document {
	my $self	= shift;
	my $node 	= $self->to_xml_dom(@_);
	
	return $node->ownerDocument if (defined($node));
	return undef;
}

#-------------------------------------------------------------------
sub _childToDom {
	my $self 	= shift;
	my $args 	= {@_};
	my $child 	= $args->{child};
	my $doc		= $args->{doc};
	
	# If the child can "to_xml_dom", then just return that
	if (UNIVERSAL::can($child, "to_xml_dom")) {
		return $child->to_xml_dom(@_);
	}
		
	# Otherwise, we'll just stringify the child and return an element with a text node.
	my $name	= $args->{name} or die "Pastor: _childToDom : Child node needs a name!\n";
	$doc						or die "Pastor: _childToDom : Need a DOM Document!\n";		
	
	# TODO : Namespaces
	my $node = $doc->createElement($name);
	
	my $text= $child . "";   # stringify

	if ($text =~~ /[<>]/) {
		# has special XML characters. Must be put in a CDATA section
		$node->appendChild( XML::LibXML::CDATASection->new( $child . "" ) ); # stringify
	} else {
		# Normal text.
		$node->appendChild( XML::LibXML::Text->new( $child . "" ) ); # stringify
	}
	
	return $node;			
}

#-------------------------------------------------------------------
# Convert the object to an XML string and write to the given file handle.
#-------------------------------------------------------------------
sub to_xml_fh {
	my $self	= shift;
	my $handle 	= shift;
	my $str		= $self->to_xml_string(@_);	
	print $handle $str;
	return $str;	
}

#-------------------------------------------------------------------
# Convert the object to an XML string and write to the given file.
#-------------------------------------------------------------------
sub to_xml_file {
	my $self	= shift;
	my $file 	= shift or die "Pastor : to_xml_file : need a file name!\n";
	my $str		= $self->to_xml_string(@_);
	
	my ($volume,$directories,$filebase) = File::Spec->splitpath( $file );
	File::Path::mkpath($volume.$directories);
	my $handle  = IO::File->new($file, "w") or die "Pastor : ComplexType : to_xml_file : Can't open file : $file\n";
	
	print $handle $str;
	$handle->close();		
	 return $str;	
}

#-------------------------------------------------------------------
# Convert the object to an XML fragment (without the <?xml ...> part)
#-------------------------------------------------------------------
sub to_xml_fragment {
	my $self	= shift;
		
    my $dom = $self->to_xml_dom(@_);
    return $dom->toString(1);
}

#-------------------------------------------------------------------
# Convert the object to an XML string.
#-------------------------------------------------------------------
sub to_xml_string {
	my $self	= shift;
		
    my $dom = $self->to_xml_dom_document(@_);    
    return $dom->toString(1);
    
}



#-------------------------------------------------------------------
# Convert the object to an XML string and PUT it to the given URL.
#-------------------------------------------------------------------
sub to_xml_url {
	my $self	= shift;
	my $url 	= shift or die "Pastor : to_xml_url : need a URL!\n";
	my $str		= $self->to_xml_string(@_);

	my $ua = LWP::UserAgent->new;
  	$ua->agent("Pastor/0.1 ");

  	# Create a request
  	my $req = HTTP::Request->new(PUT => $url);  	
	$req->content($str);
	
	# Pass request to the user agent and get a response back
	my $res = $ua->request($req);

  	# Check the outcome of the response
  	unless ($res->is_success) {
  		die "Pastor: ComplexType : to_xml_url : cannot PUT to URL '$url' : " . $res->status_line . "\n";
  	}
  	return $str;
}

#-------------------------------------------------------------------
sub xml_validate {
	my $self	= shift;
	my $path	= shift || '';
	my $type	= $self->XmlSchemaType();	

	unless ($path) {
		if (UNIVERSAL::can($self, "XmlSchemaElement")) {
			my $xmlSchemaElement = $self->XmlSchemaElement;
			$path = $xmlSchemaElement->name();
		}
	}
			
	# Attributes
	my $attributes	= $type->effectiveAttributes();
	my $attribInfo	= $type->effectiveAttributeInfo();	
	foreach my $attribName (@$attributes) {
		my $attrib = $attribInfo->{$attribName};		
		my $value = $self->{$attribName};		
				
		unless ( defined($value) ) {
			if ($attrib->use =~ /required/io) {
				die "Pastor : Validate : $path : required attribute '$attribName' is missing!";
			}else {
				next;
			}			
		}
				
		my $obj;
		if (UNIVERSAL::can($value, 'xml_validate')){
			$obj=$value;
		}else {
			my $class = $attrib->class;
			$obj = $class->new(value=>$value);
		}
		
		return 0 unless $obj->xml_validate($path . "/@" . $attribName);					
	}
	
	
	# Elements
	my $elements	= $type->effectiveElements();
	my $elementInfo	= $type->effectiveElementInfo();	
	foreach my $elemName (@$elements) {
		my $items = $self->{$elemName};
		$items = [] unless defined($items);		
		$items = [$items] unless (reftype($items) eq 'ARRAY');
		
		my $element = $elementInfo->{$elemName};
		
		if (defined($element->minOccurs) && (@$items < $element->minOccurs) ) {
				die "Pastor : Validate : $path : Element '$elemName' must occur at least '" . $element->minOccurs . "' times whereas it occurs only '" . scalar(@$items) . "' times!";			
		}

		if (defined($element->maxOccurs) && ($element->maxOccurs !~ /unbounded/io) && (@$items > $element->maxOccurs) ) {
				die "Pastor : Validate : $path : Element '$elemName' must occur at most '" . $element->maxOccurs . "' times whereas it occurs '" . scalar(@$items) . "' times!";	
		}
		
		foreach my $item (@$items) {
			if (UNIVERSAL::can($item, 'xml_validate')) {
				# The item can validate itself, no problem.
				return 0 unless $item->xml_validate($path . "/$elemName"); 
			}else {
				my $class = $element->class;
				if (UNIVERSAL::isa($class, "XML::Pastor::SimpleType")) {
					# Item should be of SimpleType, but it is not. Fix it and then validate.
					my $obj = $class->new(value => "$item");
					return 0 unless $obj->xml_validate($path . "/$elemName"); 
				}elsif (UNIVERSAL::isa($class, "XML::Pastor::ComplexType") && (reftype($item) eq 'HASH')) {
					# Item should be of ComplexType, but it is just Hash. Fix it and then validate.	
					my $obj = $class->new(%$item);
					return 0 unless $obj->xml_validate($path . "/$elemName"); 
				}else {
					die "Pastor : Validate : $path : Don't know how to validate '$elemName' (not a known or convertable type)";	
				}
			}
			
		}								
	}
	
	return 1;	
}



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

=head2 CONSTRUCTORS
 
=head4 new() 

  $class->new(%fields)

B<CONSTRUCTOR> inherited from L<XML::Pastor::Type>.

The new() constructor method instantiates a new B<XML::ComplexType> object. It is inheritable, and indeed inherited,
by the generated decsendant classes. Normally, you do not call the B<new> method on B<XML::Pastor::ComplexType>. You rather
call it on your generated classes.

  my $object = $class->new();
    
Any -named- fields that are passed as parameters are initialized to those values within
the newly created object. 

  my $object = $class->new(code=>'fr', name='France');

Notice that you can pass any field name that can be used as a hash reference. It doesn't have to 
be a valid XML attribute or child element. You may then access the same field using the usual hash access. 
You can use this feature to save state information that will not be written back to XML. Just make sure 
that the names of any such fields do not coincide with the name of actual an attribute or child element. Any such field will be 
silently ignored when writing to or validating XML. However, note that there won't be any auto-generated 
accessor for such fields. But you can actually achieve this by using the
B<mk_accessor> method from L<Class::Accessor> somewhere else in your code as B<XML::ComplexType> eventually 
inherits from L<Class::Accessor>.

.


=head4 from_xml()

  $object = $class->from_xml($resource);
  
B<CONSTRUCTOR> that should be called upon your generated class rather than B<XML::Pastor::ComplexType>.

The B<from_xml> method is a generic method that enables to instantiate a class from a variety of XML resources (DOM, URL, file, file handle, string).
The actual method that will be called will be determined by looking at the 'B<$resource>' parameter.

If 'B<$resource>' is an object (isa) of type L<XML::LibXML::Document> or L<XML::LibXML::Element>, then L</from_xml_dom> is called.

  $object = $class->from_xml($dom);


If 'B<$resource>' is an object (isa) of type L<IO::Handle>, then L</from_xml_fh> is called.

  $object = $class->from_xml($fh);


If 'B<$resource>' is an object (isa) of type L<URI>, then L</from_xml_url> is called.

  $object = $class->from_xml(URI->new('http://www.example.com/country.xml'));


If 'B<$resource>' stringifies to something that looks like a URL (currently http, https, ftp, or file), then L</from_xml_url> is called.

  $object = $class->from_xml('ftp://ftp.example.com/country.xml');

If 'B<$resource>' stringifies to something that looks like an XML string, then L</from_xml_string> is called.

  # Assuming there is a generated class called 'MyApp::Data::country'
  $country = MyApp::Data::country->from_xml(<<'EOF');
  
  <?xml version="1.0"?>
  <country code="FR" name="France">
    <city code="PAR" name="Paris"/>
    <city code="LYO" name="Lyon"/>    
  </country>
  EOF
  
Otherwise, 'B<$resource>' is assumed to be a file name and subsequently L</from_xml_file> is called.

  $object = $class->from_xml('/tmp/country.xml');

.

=head4 from_xml_dom()

  $object = $class->from_xml_dom($dom);
  
B<CONSTRUCTOR> that should be called upon your generated class rather than B<XML::Pastor::ComplexType>.
  
This method instatiates an object of the generated class from a DOM object passed as a parameter. Currently, the DOM
object must be either of type L<XML::LibXML::Document> or of type L<XML::LibXML::Element>.

Currently, the method is quite forgiving as to the actual contents of the DOM. Attributes and child elements that fit the 
original W3C schema defined names will be imported as I<fields> of the newly created object. Those that don't fit the schema 
will silently be ignored. So there are very few circumstances that this method will B<die> or return 'B<undef>'. Most usually, at worst
the object returned will be completely empty (if the XML DOM had nothing to do with the W3C schema definition) but will still be correctly typed.

.

=head4 from_xml_fh()

  $object = $class->from_xml_fh($fh);
  
B<CONSTRUCTOR> that should be called upon your generated class rather than B<XML::Pastor::ComplexType>.
  
This method instatiates an object of the generated class from an XML string parsed from a file handle passed 
as an argument.

The contents of the file handle will be parsed using the B<parse_fh> method of L<XML::LibXML>. If the parser dies,  
this method will also B<die>. The DOM that is obtained from the parser will be passed to L</from_xml_dom> for further processing.

Currently, the method is quite forgiving as to the actual contents of the DOM. See L</from_xml_dom> for more information on this. 

.

=head4 from_xml_file()

  $object = $class->from_xml_file($fileName);
  
B<CONSTRUCTOR> that should be called upon your generated class rather than B<XML::Pastor::ComplexType>.
  
This method instatiates an object of the generated class from an XML string parsed from a file whose name passed 
as an argument.

The contents of the file handle will be parsed using the B<parse_file> method of L<XML::LibXML>. If the parser dies,  
this method will also B<die>. The DOM that is obtained from the parser will be passed to L</from_xml_dom> for further processing.

Currently, the method is quite forgiving as to the actual contents of the DOM. See L</from_xml_dom> for more information on this. 

.

=head4 from_xml_fragment()

  $object = $class->from_xml_fragment($fragment);
  
B<CONSTRUCTOR> that should be called upon your generated class rather than B<XML::Pastor::ComplexType>.
  
This method instatiates an object of the generated class from an XML fragment passed 
as an argument.

  # Assuming there is a generated class called 'MyApp::Data::country'
  $country = MyApp::Data::country->from_xml_fragment(<<'EOF');
  
  <country code="FR" name="France">
    <city code="PAR" name="Paris"/>
    <city code="LYO" name="Lyon"/>    
  </country>
  EOF

The difference between an XML fragment and an XML string is that in XML fragment the C<?xml version="1.0"?> is missing.
This method will prepend this to the scalar that is passed as an argument and then simply call L</from_xml_string>.

Currently, the method is quite forgiving as to the actual contents of the DOM. See L</from_xml_dom> for more information on this. 


.

=head4 from_xml_string()

  $object = $class->from_xml_string($scalar);
  
B<CONSTRUCTOR> that should be called upon your generated class rather than B<XML::Pastor::ComplexType>.
  
This method instatiates an object of the generated class from an XML string passed 
as an argument.

  # Assuming there is a generated class called 'MyApp::Data::country'
  $country = MyApp::Data::country->from_xml_string(<<'EOF');

  <?xml version="1.0"?>  
  <country code="FR" name="France">
    <city code="PAR" name="Paris"/>
    <city code="LYO" name="Lyon"/>    
  </country>
  EOF

The contents of the string will be parsed using the B<parse_string> method of L<XML::LibXML>. If the parser dies,  
this method will also B<die>. The DOM that is obtained from the parser will be passed to L</from_xml_dom> for further processing.

Currently, the method is quite forgiving as to the actual contents of the DOM. See L</from_xml_dom> for more information on this. 

.

=head4 from_xml_url()

  $object = $class->from_xml_url($url);
  
B<CONSTRUCTOR> that should be called upon your generated class rather than B<XML::Pastor::ComplexType>.
  
This method instatiates an object of the generated class from an XML document that can be retrieved with the B<GET> method 
from the URL passed as an argument. The URL can be a scalar or a URI object.

This method will first slurp the contents of the URL using the B<GET> method via L<LWP::UserAgent>. If the retrieval did not 
go well, the method will B<die>.

Then, the content so retrieved will be parsed using the B<parse_string> method of L<XML::LibXML>. If the parser dies,  
this method will also B<die>. The DOM that is obtained from the parser will be passed to L</from_xml_dom> for further processing.

Currently, the method is quite forgiving as to the actual contents of the DOM. See L</from_xml_dom> for more information on this. 

.

=head2 XML STORAGE METHODS

=head4 to_xml()

  $object->to_xml($resource, %options);
  
B<OBJECT METHOD> that may be called upon objects of your generated complex classes.

The B<to_xml> method is a generic method that enables to store an object in XML to a variety of XML resources (DOM, URL, file, file handle, string).
The actual method that will be called will be determined by looking at the 'B<$resource>' parameter.

Currently, B<%options> may contain a field called B<name> which is necessary only when the class corresponds to a complex type definition in the schema.
When it corresponds to a global element, the name of the element is already known, but in other cases this information must be supplied. In fact, B<Pastor> 
carries out a last ditch effort to recover the name of the element if it has been previously been parsed from DOM, but don't count on this. The rule of the thumb is, 
if your class corresponds to a global element, you do NOT have to provide a B<name> for the element to be written. Otherwise, you do have to provide it.
 
If 'B<$resource>' is an object (isa) of type L<IO::Handle>, then L</to_xml_fh> is called.

  $object->to_xml($fh);

or, if the object is not a class that corresponds to a global element,

  $object->to_xml($fh, name=>country);	# asssuming you would like to save this complex object as the element 'country'
  
If 'B<$resource>' is an object (isa) of type L<URI>, then L</to_xml_url> is called.

  $object->to_xml(URI->new('http://www.example.com/country.xml'));


If 'B<$resource>' stringifies to something that looks like a URL (currently http, https, ftp, or file), then L</to_xml_url> is called.

  $object ->to_xml('ftp://ftp.example.com/country.xml');

If 'B<$resource>' is a scalar reference or B<undef>, then L</to_xml_string> is called and the result is returned.

  $output = $object->to_xml();
  
Otherwise, 'B<$resource>' is assumed to be a file name and subsequently L</to_xml_file> is called.

  $object->to_xml('/tmp/country.xml');

.

=head4 to_xml_dom()

  $object->to_xml_dom(%options);
  
B<OBJECT METHOD> that may be called upon objects of your generated complex classes.

This method stores the XML contents of a generated complex class in a LibXML DOM node and returns the resulting node (element).  

Currently, B<%options> may contain a field called B<name> which is necessary only when the class corresponds to a complex type definition in the schema.
When it corresponds to a global element, the name of the element is already known, but in other cases this information must be supplied. In fact, B<Pastor> 
carries out a last ditch effort to recover the name of the element if it has been previously been parsed from DOM, but don't count on this. The rule of the thumb is, 
if your class corresponds to a global element, you do NOT have to provide a B<name> for the element to be written. Otherwise, you do have to provide it.

For a class corresponding to a B<global element>:

	$dom = $object->to_xml_dom();

or, for a class corresponding to B<complex type definition>:

	$dom = $object->to_xml_dom(name=>'country'); # Assuming you want your element to be called 'country'.

No validation occurs proir to storage. If you want that, please do it yourself beforehand using L</xml_validate> or L</is_xml_valid>.
	
.

=head4 to_xml_dom_document()

  $object->to_xml_dom_document(%options);
  
B<OBJECT METHOD> that may be called upon objects of your generated complex classes.

This method stores the XML contents of a generated complex class in a LibXML DOM node and returns the owner document node of type L<XML::LibXML::Document>.  
   
For the B<%options> please see L</to_xml_dom>.

For a class corresponding to a B<global element>:

	$dom_doc = $object->to_xml_dom_document();

or, for a class corresponding to B<complex type definition>:

	$dom_doc = $object->to_xml_dom_document(name=>'country'); # Assuming you want your ROOT element to be called 'country'.

No validation occurs proir to storage. If you want that, please do it yourself beforehand using L</xml_validate> or L</is_xml_valid>.

.

=head4 to_xml_fh()

  $object->to_xml_fh($fh, %options);
  
B<OBJECT METHOD> that may be called upon objects of your generated complex classes.

This method writes the XML contents of a generated complex class in a file handle (L<IO::Handle>) passed
as the first argument 'B<$fh>'.
   
For the B<%options> please see L</to_xml_dom>.

For a class corresponding to a B<global element>:

	$object->to_xml_fh($fh);

or, for a class corresponding to B<complex type definition>:

	$object->to_xml_fh($fh, name=>'country'); # Assuming you want your ROOT element to be called 'country'.

No validation occurs proir to storage. If you want that, please do it yourself beforehand using L</xml_validate> or L</is_xml_valid>.

.

=head4 to_xml_file()

  $object->to_xml_file($fileName, %options);
  
B<OBJECT METHOD> that may be called upon objects of your generated complex classes.

This method writes the XML contents of a generated complex class in a file given
by the first argument 'B<$fileName>'.
   
For the B<%options> please see L</to_xml_dom>.

For a class corresponding to a B<global element>:

	$object->to_xml_file('/tmp/country.xml');

or, for a class corresponding to B<complex type definition>:

	$object->to_xml_fh('/tmp/country.xml', name=>'country'); # Assuming you want your ROOT element to be called 'country'.

No validation occurs proir to storage. If you want that, please do it yourself beforehand using L</xml_validate> or L</is_xml_valid>.

.

=head4 to_xml_fragment()

  $object->to_xml_fragment(%options);
  
B<OBJECT METHOD> that may be called upon objects of your generated complex classes.

This method generates the fragment XML contents of a generated complex class and returns the resulting string.
The difference between this method and L</to_xml_string> is that this method calls the B<toString> method on the 
root DOM node rather than the DOM DOCUMENT. Presumably, this will result in the absence of the C<?xml> tag with version 
and the encoding information in the beginning of the string.
   
For the B<%options> please see L</to_xml_dom>.

For a class corresponding to a B<global element>:

	$object->to_xml_fragment();

or, for a class corresponding to B<complex type definition>:

	$object->to_xml_fragment(name=>'country'); # Assuming you want your ROOT element to be called 'country'.

No validation occurs proir to storage. If you want that, please do it yourself beforehand using L</xml_validate> or L</is_xml_valid>.

.

=head4 to_xml_string()

  $object->to_xml_string(%options);
  
B<OBJECT METHOD> that may be called upon objects of your generated complex classes.

This method generates the XML contents of a generated complex class and returns the resulting string corresponding to an XML document.
The difference between this method and L</to_xml_fragment> is that this method calls the B<toString> method on the 
DOM DOCUMENT node rather than the root DOM node (element). 
   
For the B<%options> please see L</to_xml_dom>.

For a class corresponding to a B<global element>:

	$object->to_xml_string();

or, for a class corresponding to B<complex type definition>:

	$object->to_xml_string(name=>'country'); # Assuming you want your ROOT element to be called 'country'.

No validation occurs proir to storage. If you want that, please do it yourself beforehand using L</xml_validate> or L</is_xml_valid>.

.

=head4 to_xml_url()

  $object->to_xml_url($url, %options);
  
B<OBJECT METHOD> that may be called upon objects of your generated complex classes.

This method writes the XML contents of a generated complex class in a URL given
by the first argument 'B<$url>'(either a string or a L<URI> object) via the HTTP B<PUT> method.  

Note that B<LWP::UserAgent> does not currently support the B<PUT> method on B<file> URLs. 
So if you try this on a B<file> URL, the method will B<die>.
   
For the B<%options> please see L</to_xml_dom>.

For a class corresponding to a B<global element>:

	$object->to_xml_url(URI->new('http://www.example.com/country.xml'));

or, for a class corresponding to B<complex type definition>:

	$object->to_xml_url('http://www.example.com/country.xml', name=>'country'); # Assuming you want your ROOT element to be called 'country'.

No validation occurs proir to storage. If you want that, please do it yourself beforehand using L</xml_validate> or L</is_xml_valid>.

.

=head2 CLASS METHODS

=head4 is_xml_field_singleton()

  $bool = $class->is_xml_field_singleton($fieldName);

B<CLASS METHOD>, but may also be called directly on an B<OBJECT>. 

'B<is_xml_field_singleton>' will return TRUE if the I<field> (attribute or child element) given by the B<$fieldName> parameter
corresonds to a child element with a 'B<maxOccurs>' of 'B<1>' or 'B<undef>'. A field that corresponds to an B<attribute> will always return 
TRUE as attributes cannot have multiple values.

  $bool = $object->is_xml_field_singleton('city');	# assuming there is an attribute or child element called 'city'.

Note that the current value of the corresponding I<field> is irrelevant for this method. It is the B<W3C schema> information that matters.

See L</is_xml_field_multiple> for more info.

.

=head4 is_xml_field_multiple()

  $className = $class->xml_field_class($fieldName);

B<CLASS METHOD>, but may also be called directly on an B<OBJECT>. 

'B<is_xml_field_multiple>' will return the negation of the boolean value returned by 
L</is_xml_field_singleton>. See L</is_xml_field_singleton> for more information. 
A field that corresponds to an attribute will always return FALSE as attributes 
cannot have multiple values.
  
  $bool = $object->is_xml_field_multiple('city');	# assuming there is an attribute or child element called 'city'.

As a side note, notice that child elements that can I<potentially> have multiple values will always be put in a L<XML::Pastor::NodeArray> object when
being read from XML, or when B<grab>bed. This is regardless of the actual multiplicity of the current value of the field. That is, the multiplicity 
depends only on the 'B<maxOccurs>' property defined in the B<W3C Schema>.

L<XML::Pastor::NodeArray> objects have some magical properties that occur thanks to hash access overloading and the AUTOLOAD method that enable them to be used 
as an array of fields or as if it were a reference to the first node in the array. See L<XML::Pastor::NodeArray> for more details.

When writing to or validating XML, L<XML::Pastor> is quite forgiving. Non-array (singleton) values are accepted as if they were an array having only one item inside.

.

=head4 xml_field_class()

  $className = $class->xml_field_class($fieldName);

B<CLASS METHOD>, but may also be called directly on an B<OBJECT>. 

'B<xml_field_class>' returns the B<class name> for a given I<field> (attribute or child element) by doing a look-up in the META 
B<W3C Schema> type information via B<XmlSchemaType> class data accessor. 

If the I<field> given by the B<$fieldName> parameter cannot be found, the method will return B<undef>.

When defined, the returned class name, which is typically the name of generated class, is guaranteed to be a descendent of either 
B<XML::Pastor::ComplexType> or L<XML::Pastor::SimpleType>.

  $class = $country->xml_field_class('city');	# assuming there is an attribute or child element called 'city'.
  $city	 = $class->new(name=>'Paris');

This is the preferred method of obtaining class names for child elements or attributes instead of hard-coding them in your program. 
This way, your program only I<knows> about the names of classes corresponding to B<global elements> and the rest is obtained at run-time
via B<xml_field_class>.

.

=head2 CLASS DATA ACCESSORS

=head4 XmlSchemaType()

  $type = $class->XmlSchemaType()
  
B<CLASS METHOD>, but may also be called directly on an B<OBJECT>. 

Thanks to L<Class::Data::Inheritable>, B<XML::Pastor::ComplexType> defines  
a class data acessor B<XmlSchemaType> which returns B<undef> when called on this class. 
However, this data accessor is set by each generated complex class to the meta information coming from your B<W3C Schema>. 
This data is of class L<XML::Pastor::Schema::ComplexType>. 

You don't really need to know much about B<XmlSchemaType>. It's used internally by Pastor's XML binding and validation 
methods as meta information about the generated class. 

However, if you are curious about how B<Pastor> works, you can check out L<XML::Pastor::Schema::ComplexType>.
 

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

=head4 grab()

  $field = $object->grab($fieldName);

'B<grab>' will return the value of the I<field> (attribute or child element) given by the B<$fieldName> parameter. If the I<field> does not exist, it will
be automatically created (cally 'B<new()>' on the right class) and stuffed into the complex object.

  $field = $object->grab('code');	#assuming there is an attribute or child element called 'code'.
  
Normally, you use the corresponding B<accessor method> to get at the I<field> (attribute or child element) of your choosing.
The accessor will normally return B<'undef'> when the corresponding field does not exist in the object. 

Sometimes, this is not what you desire. For example, when you will change the value of the field after reading it anyway, or when you will
manipulate a child element of the field after calling the accessor anyway. This is where B<grab> comes into play. 

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

=head4 xml_validate()

  $bool = $object->xml_validate();	# May die on you on validation errors.

B<OBJECT METHOD>, overriden from L<XML::Pastor::Type>.

'B<xml_validate>' validates a Pastor XML object (of a generated class) with respect to the META information that
had originally be extracted from your original B<W3C XSD Schema>.

On sucess, B<xml_validate> returns TRUE (1). On failure, it will B<die> on you on validation errors. 

The W3C recommendations have been observed as closely as possible for the implementation of this method. 
Neverthless, it remains somewhat more relaxed and easy compared to B<Castor> for example.

One important note is that extra I<fields> (those that do not correspond to an attribute or child element as defined by W3C schema)
that may be present in the object are simply ignored and left alone. This has the advantage that you can actually store state 
information in the generated objects that are not destined to XML storage. 

Another important behavior is the fact that even when you have multiple child elements for one that should have been a singleton, this does not 
trigger an error. Instead, only the first one is considered. 

The absence of a required I<field> (attribute or child element) is an error however. Furthermore, the validity of each attribute or child element is 
also checked by calling B<xml_validate> on their respective classes even if you have only put a scalar in those. This means that such objects are created 
during validation on the fly whose values are set to the scalar present. But such validation induced objects are not stored back to the object and the scalars are left alone.
 
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

See also L<XML::Pastor>, L<XML::Pastor::SimpleType>

And if you are more curious, see L<XML::Pastor::Type> (the ancestor of this class), 
L<XML::Pastor::Schema::ComplexType> (meta type information from your B<W3C schema>)

And if you are even more curious, see L<Class::Accessor>, L<Class::Data::Inheritable>


=cut

