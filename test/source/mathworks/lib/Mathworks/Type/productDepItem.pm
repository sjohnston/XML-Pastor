
#PASTOR: Code generated by XML::Pastor/0.54 at 'Sat Jul 12 15:24:21 2008'

use utf8;
use strict;

use XML::Pastor;



#================================================================

package MathWorks::Type::productDepItem;


our @ISA=qw(XML::Pastor::ComplexType);

MathWorks::Type::productDepItem->mk_accessors( qw(_name));

# Attribute accessor aliases

sub name { &_name; }

MathWorks::Type::productDepItem->XmlSchemaType( bless( {
                 'attributeInfo' => {
                                    'name' => bless( {
                                                     'class' => 'XML::Pastor::Builtin::string',
                                                     'name' => 'name',
                                                     'scope' => 'local',
                                                     'type' => 'string|http://www.w3.org/2001/XMLSchema',
                                                     'use' => 'required'
                                                   }, 'XML::Pastor::Schema::Attribute' )
                                  },
                 'attributePrefix' => '_',
                 'attributes' => [
                                   'name'
                                 ],
                 'baseClasses' => [
                                    'XML::Pastor::ComplexType'
                                  ],
                 'class' => 'MathWorks::Type::productDepItem',
                 'contentType' => 'complex',
                 'elementInfo' => {},
                 'elements' => [],
                 'isRedefinable' => 1,
                 'name' => 'productDepItem',
                 'scope' => 'global'
               }, 'XML::Pastor::Schema::ComplexType' ) );

1;
