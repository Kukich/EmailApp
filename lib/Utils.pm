package Utils;


use base 'Exporter';
use YAML::Any qw(Dump LoadFile DumpFile);
our @EXPORT = qw(check_filters LoadYamlFile check_params generateID);
use Data::Dumper;
use strict;
use Mojo::Home;

sub LoadYamlFile {
    my $file = shift || '';
    die "\t File: $file doesn't exists" unless -f $file;
    return LoadFile($file);
}

sub check_params{
	my $hash = shift;
	my @err;
	print Dumper($hash);
	my $required_params = [qw/to subject sender message/];
	@err = check_existing_params($required_params,$hash);
	return @err if scalar(@err);
	foreach my $p(@$required_params){
		unless($p eq 'to'){
			push @err,"input $p is not string" unless ref $hash->{$p} eq '';
		}
		if ($p eq 'to' && (my $to_error = check_to($hash->{$p}))){
			push @err,$to_error;
		}
	}
	return @err;
}

sub check_to{
	my $to = shift;
	if(ref $to eq ''){
		return "bad email \`to\` ".$to unless check_email($to);
	}elsif(ref $to eq 'ARRAY'){
		foreach my $s(@$to){
			return "bad email \`to\` ".$s unless check_email($s);
		}
	}else{
		return "bad email \`to\` format ";
	}
	return "";
}


sub check_email{
	my $email = shift;
	my $ok = $email =~ /.+@.+\..+/i ? 1 : 0;
	return $ok
}

sub check_existing_params{
	my $required_params = shift;
	my $hash = shift;
	my @err;
	foreach my $p(@$required_params){
		push @err, 'not input param '.$p unless exists $hash->{$p};
	}
	return @err;
}


sub check_filters{
	my $params = shift;
	my @err;
	foreach my $p(qw/page per_page/){
		if(exists $params->{$p}){
			push @err, $p . ' is not digit' if $params->{$p} !~ /^[1-9]+0?$/;
		}
	}
	return @err;
}

sub generateID {
	my @pass = ();
	my $possible = 'abcdefghijkmnpqrstuvwxyz123456789';
	for (1..5){
		my $length = 0;
		my $pass="";
		while (5 > $length) {
			$pass .= substr($possible, (int(rand(length($possible)))), 1);
			$length++;
		}
		push @pass,$pass;
	}
	return join('-',@pass);
}
1;