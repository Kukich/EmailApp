package EmailsAppMongo;
use Exporter qw( import );
use MongoDB;
use MongoDB::Code;
use Data::Dumper;
use DateTime;
use strict;
use Encode;
use Tie::IxHash;


sub new{
	my $class = shift;
	my $config = shift;
	my $self = {};
	bless $self,$class;
	$self->{client} = MongoDB::MongoClient->new(
            host           => $config->{host},
            port           => $config->{port},
            auto_connect   => 0,
            auto_reconnect => 1,
	        socket_timeout_ms => $config->{timeout} || 30000,
            timeout       => $config->{timeout} || 30000,
            query_timeout => $config->{timeout} || 30000,
        );
	$self->{db_name} = $config->{db_name};
    return $self if ((ref $self->{client} eq 'MongoDB::MongoClient') and $self->{client}->get_database($self->{db_name})->run_command({ 'ping' => 1 }));
    die "No connect to mongo!";
}

sub collection{
	my $self = shift;
	my $collection_name = shift;
	$self->{collection} = $self->{client}->get_database($self->{db_name})->get_collection($collection_name);
}

sub insert_mail{
	my $self = shift;
	my $input_data = shift;
	my $id = shift;
	print "insert_mail start\n";
	$input_data->{created_at} = time;
	$input_data->{sent_status} = 0;
	$input_data->{id} = $id;
	my $res = $self->{collection}->insert_one($input_data);
	my $mongo_id = $res->inserted_id;
	print "insert_mail end , inserted_id = $mongo_id \n";
	return $mongo_id;
}

sub get_mail{
	my $self = shift;
	my $id = shift;
	print "get_mail start for id = $id \n";
	print $id."\n";
	my $tz = DateTime::TimeZone->new(name => "local");
	my $result = $self->{collection}->find_one({id=>$id});
	if($result){
		my $dt = DateTime->from_epoch( epoch=>$result->{created_at},time_zone => $tz);
		delete $result->{_id} if exists $result->{_id};
		$result->{'created_at'} => $dt->datetime;
	}
	print "get_mail end\n";
	return $result;
}

sub get_mails{
	my $self = shift;
	my $filter = shift;
	my $mojo = shift;
	print "get_mails start \n";
	my $tz = DateTime::TimeZone->new(name => "local");
	my $page = $filter->{page};
	my $per_page = $filter->{per_page};
	my $size = $self->{collection}->count(); #Количество записей
	my $cnt = int($size/$per_page-0.0000000000005)+1; #Количество страниц
	my $next_page = ($cnt - $page > 0 ? $page+1 : 0);
	my $prev_page = ($cnt =~/^(1|0)$/? 0 : $page - 1);
	my $results=[];
	if ($cnt){
	  my %sort;
	  tie ( %sort, 'Tie::IxHash' );
	  my $sort = \%sort;
	  my $cursor = $self->{collection}->find()->sort($sort)->skip(($filter->{page}-1)*$filter->{per_page})->limit($filter->{per_page});
	  while(my $email = $cursor->next) {
		 delete $email->{_id};
		 my $dt = DateTime->from_epoch( epoch=>$email->{created_at},time_zone => $tz);
		 push @$results,{%$email,'created_at' => $dt->datetime};
	  }
	}
	my $headers = {
		'X-Total' => $size,
		'X-Total-Pages' => $cnt ,
		'X-Per-Page' => $filter->{per_page},
		'X-Page' => $filter->{page}
	};
	$headers->{'X-Next-Page'} = $next_page if $next_page;
	$headers->{'X-Prev-Page'} = $prev_page if $prev_page;
	print "get_mails end \n";
	return ($results,$headers);
}
1;