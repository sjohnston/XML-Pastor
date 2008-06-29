use utf8;
use Test::More tests=>29;

use_ok('URI');
use_ok('URI::file');
use_ok ('XML::Pastor');


my $pastor = XML::Pastor->new();
	
$pastor->generate(	mode =>'eval',
					schema=>['./test/schema/schema3.xsd'], 
					class_prefix=>"XML::Pastor::Test",
					destination=>'./test/out/lib/', 					
					verbose =>0
				);
				
				
# ======= COUNTRY ==============				
my $country = XML::Pastor::Test::country->from_xml(URI::file->new_abs('./test/xml/country.xml'));

ok(defined($country), 'defined country');

my @ancestors = qw( XML::Pastor::Type 
					XML::Pastor::ComplexType 
					XML::Pastor::Element
					XML::Pastor::Test::country
					);

foreach my $ancestor (@ancestors) {
	isa_ok($country, $ancestor, 'country');
}

# XML::Pastor::Type methods
can_ok(	$country, 
		qw(
			new
			is_xml_valid
			xml_validate
			xml_validate_futher
		));

# XML::Pastor::Type class methods
can_ok($country, 
		qw( 
			XmlSchemaType 
			));
			

# XML::Pastor::ComplexType methods
can_ok($country, 
		qw( 	xml_field_class 
				is_xml_field_singleton 
				is_xml_field_multiple
				get
				set 
				grab 
				from_xml_dom 
				from_xml 
				from_xml_file
				from_xml_fh
				from_xml_fragment
				from_xml_string
				from_xml_url
				to_xml
				to_xml_dom
				to_xml_dom_document));

# XML::Pastor::Element class methods
can_ok($country, 
		qw( 
			XmlSchemaElement 
			));

# Field accessor methods
can_ok($country, 
		qw( 
			code
			name
			city
			currency
			population 
			));



# ======= COUNTRY CODE =========
my $country_code = $country->code;

ok(defined($country_code), 'defined country code');

# ISA tests
@ancestors = qw( 	XML::Pastor::Type 
					XML::Pastor::SimpleType 
					);

foreach my $ancestor (@ancestors) {
	isa_ok($country_code, $ancestor, 'country code');
}

# XML::Pastor::Type methods
can_ok(	$country_code, 
		qw(
			new
			is_xml_valid
			xml_validate
			xml_validate_futher
		));

# XML::Pastor::Type class methods
can_ok($country_code, 
		qw( 
			XmlSchemaType 
			));
			

# XML::Pastor::SimpleType methods
can_ok($country_code, 
		qw( 	from_xml_dom
				xml_validate
				xml_validate_further
				normalize_whitespace
		));

# Accessor methods
can_ok($country_code, 
		qw( 
			value
			));




# ===== EXPECTED VALUES =========
my $expected;

# Check the country code
$expected = 'fr';
is(lc($country->code), lc($expected), "country code");

# Check the country name
$expected = 'france';
is(lc($country->name), lc($expected), "country name");

# Defined city
my $cities = $country->city;
ok(defined($cities), 'defined cities');

# Get a hash of the cities on 'code' attribute
my $city_h = $cities->hash('code');
my $code;
my $city;

# Check the name of a given city
$code = 'AVA';
$city = $city_h->{$code};
$expected = 'Ambrières-les-Vallées';
is(lc($city->name), lc($expected), "city name '". $code . "'");

# Check the name of a given city
$code = 'BCX';
$city = $city_h->{$code};
$expected = 'Beire-le-Châtel';
is(lc($city->name), lc($expected), "city name '". $code . "'");

# Check the name of a given city
$code = 'LYO';
$city = $city_h->{$code};
$expected = 'Lyon';
is(lc($city->name), lc($expected), "city name '". $code . "'");

# Check the name of a given city
$code = 'NCE';
$city = $city_h->{$code};
$expected = 'Nice';
is(lc($city->name), lc($expected), "city name '". $code . "'");

# Check the name of a given city
$code = 'PAR';
$city = $city_h->{$code};
$expected = 'Paris';
is(lc($city->name), lc($expected), "city name '". $code . "'");


#	print STDERR "\nTest OVER baby!\n";			
ok(1, 'end');	# survived everything
  

1;

