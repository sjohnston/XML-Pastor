
#PASTOR: Code generated by XML::Pastor/0.54 at 'Sat Jul 12 15:24:21 2008'

use utf8;
use strict;

use XML::Pastor;



#================================================================

package MathWorks::productDepItem;

use MathWorks::Type::productDepItem;

our @ISA=qw(MathWorks::Type::productDepItem XML::Pastor::Element);

MathWorks::productDepItem->XmlSchemaElement( bless( {
                 'baseClasses' => [
                                    'MathWorks::Type::productDepItem',
                                    'XML::Pastor::Element'
                                  ],
                 'class' => 'MathWorks::productDepItem',
                 'isRedefinable' => 1,
                 'name' => 'productDepItem',
                 'scope' => 'global',
                 'type' => 'productDepItem'
               }, 'XML::Pastor::Schema::Element' ) );

1;
