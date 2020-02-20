package EmailsAppRedis;

use Redis;
use Try::Tiny;
use Data::Dumper;
use Exporter qw( import );

sub new{
	my $class = shift;
	my $config = shift;
	my $self = {};
	bless $self,$class;
	$self->{redis} = my $redis = Redis->new(
			server => $config->{host},
			reconnect => $config->{reconnect} || 60,
			every => $config->{every} || 5000
	);
	foreach my $key(qw/channel group reader/){
		$self->{config}->{$key} = $config->{$key};
	}
    $self->{redis}->ping || die "redis do not answer";
    return $self;
}

sub insert_message{
	my $self = shift;
	my @params = @_;
	print "insert_message start\n";
	print "xadd ".$self->{config}->{channel}." * ".join(' ',@params)."\n";
	my $id = $self->{redis}->xadd($self->{config}->{channel}, "*" ,@params);
	print "insert_message end with id=$id \n";
	return $id;
}

sub check_channel{
	my $self = shift;
	my $ok = 0;
	print "check_channel start\n";
	while(1){
		my $info;
		try{
			print "xinfo ".' stream '.$self->{config}->{channel};
			$info = $self->{redis}->xinfo('stream',$self->{config}->{channel});
			$ok = 1;
		}catch{
			$ok = 0;
			unless ($_ =~ /ERR no such key/){
				print STDERR $_ ."\n";
				last;
			}
			print "time to wait"."\n";
		};
		last if ($info);
		sleep(1);
	}
	print "check_channel end\n";
	return $ok;
}

sub create_group{
	my $self = shift;
	print "create_group start \n";
	try{
		print "xgroup ".'create'." ".$self->{config}->{channel}." ".$self->{config}->{group}." "."0"."\n";
		$self->{redis}->xgroup('create',$self->{config}->{channel},$self->{config}->{group},0);
	}catch{
		unless($_ =~ /BUSYGROUP Consumer Group name already exists/){
			print STDERR $_."\n";
		}
	};
	print "create_group end \n";
}
sub check_messages{
	my $self = shift;
	print "check_messages start\n";
	print "xpending ".$self->{config}->{channel}." ".$self->{config}->{group}." ".'-'." ".'+'." "."1"." ".$self->{config}->{reader}."\n";
	my $messages = $self->{redis}->xpending($self->{config}->{channel},$self->{config}->{group},'-','+',1,$self->{config}->{reader});
	print "check_messages end\n";
	return $messages;
}
sub proccessed_message{
	my $self = shift;
	my $redis_id = shift;
	print "proccessed_message start\n";
	print "xack Group"." ". $self->{config}->{channel}." ". $self->{config}->{group}." ".$redis_id."\n";
	$self->{redis}->xack($self->{config}->{channel},$self->{config}->{group},$redis_id);
	print "proccessed_message end\n";
}
sub read_group{
	my $self = shift;
	print "read_group start\n";
	print "xreadgroup Group"." ". $self->{config}->{group}." ". $self->{config}->{reader}." "."count"." "."1"." "."streams"." ".$self->{config}->{channel}." ". ">"."\n";
	my $new_messages = $self->{redis}->xreadgroup("Group", $self->{config}->{group}, $self->{config}->{reader},"count","1","streams",$self->{config}->{channel}, ">");
	print "read_group end\n";
	return $new_messages;
}

sub get_data{
	my $self = shift;
	my $redis_id = shift;
	print "get_data start\n";
	print "xrange ".$self->{config}->{channel}." ".$redis_id." ".$redis_id."\n";
	my $result = $self->{redis}->xrange($self->{config}->{channel},$redis_id,$redis_id);
	print "get_data end,we have id = ".$result->[0]->[1]->[1]."\n";
	return $result->[0]->[1]->[1];
}

1;