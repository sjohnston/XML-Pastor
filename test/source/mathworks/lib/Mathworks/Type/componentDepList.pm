
#PASTOR: Code generated by XML::Pastor/0.54 at 'Sat Jul 12 15:24:21 2008'

use utf8;
use strict;

use XML::Pastor;



#================================================================

package MathWorks::Type::componentDepList;

use MathWorks::Type::componentDepItem;

our @ISA=qw(XML::Pastor::ComplexType);

MathWorks::Type::componentDepList->mk_accessors( qw(componentDep));

MathWorks::Type::componentDepList->XmlSchemaType( bless( {
                 'attributeInfo' => {},
                 'attributePrefix' => '_',
                 'attributes' => [],
                 'baseClasses' => [
                                    'XML::Pastor::ComplexType'
                                  ],
                 'class' => 'MathWorks::Type::componentDepList',
                 'contentType' => 'complex',
                 'elementInfo' => {
                                  'componentDep' => bless( {
                                                           'class' => 'MathWorks::Type::componentDepItem',
                                                           'maxOccurs' => 'unbounded',
                                                           'name' => 'componentDep',
                                                           'scope' => 'local',
                                                           'type' => 'componentDepItem'
                                                         }, 'XML::Pastor::Schema::Element' )
                                },
                 'elements' => [
                                 'componentDep'
                               ],
                 'isRedefinable' => 1,
                 'name' => 'componentDepList',
                 'scope' => 'global'
               }, 'XML::Pastor::Schema::ComplexType' ) );

1;