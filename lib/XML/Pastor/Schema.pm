use utf8;
use strict;

use XML::Pastor::Schema::Attribute;
use XML::Pastor::Schema::AttributeGroup;
use XML::Pastor::Schema::ComplexType;
use XML::Pastor::Schema::Context;
use XML::Pastor::Schema::Element;
use XML::Pastor::Schema::Group;
use XML::Pastor::Schema::List;
use XML::Pastor::Schema::Model;
use XML::Pastor::Schema::NamespaceInfo;
use XML::Pastor::Schema::Object;
use XML::Pastor::Schema::Parser;
use XML::Pastor::Schema::SimpleType;
use XML::Pastor::Schema::Union;

package XML::Pastor::Schema;
our @ISA = qw(XML::Pastor::Schema::Object);

XML::Pastor::Schema->mk_accessors(
qw(	targetNamespace 	 	 
	attributeFormDefault 	elementFormDefault));

1;
