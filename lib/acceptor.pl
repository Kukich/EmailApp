#!/usr/local/bin/perl

 
use lib "./";
use EmailsAppMongo;
use EmailsAppRedis;
use Utils qw/check_filters LoadYamlFile check_params generateID/;
use Try::Tiny;
use Data::Dumper;

#============test_input==========================
my $filters = {
	per_page => 15,
};

my @hashes=(
#{subject => 'subject',to => ['mrkuk89@gmail.com','mrkuk@yandex.ru'], sender => 'Sender1',message => 'Very important message (first time)'},
{subject => 'subject',to => 'kukichtest@yandex.ru', sender => 'Sender2',message => 'не погу понять что происходит'},
{subject => 'subject'},
{to => ['from@a.ru'],},
{subject => 'subject',to => ['to@a.ru','asdfasdf'], sender => ['from@a.ru'],message => 'message3',},
);

#==========init==================================
my $config = LoadYamlFile('conf.yaml');
my $redis_config = $config->{redis};
my $emails_app_redis = EmailsAppRedis->new($redis_config);
my $mongo_config = $config->{mongo};
my $emails_app_mongo = EmailsAppMongo->new($mongo_config);
$emails_app_mongo->collection($mongo_config->{collection});
#============check_params=======================
foreach my $hash(@hashes){
	print "=============================================\n";
	my @err = check_params($hash);
	if(scalar(@err)){
		foreach my $e(@err){
			print $e."\n";
		}
	}else{
		print "process_message\n";
		my $ok = process_message($hash,$emails_app_mongo,$emails_app_redis);
		print "ALL IS OK\n" if $ok;
		print "process_message END\n";
	}
	print "=============================================\n";
}
my ($results,$header) = $emails_app_mongo->get_mails({per_page=>5,page=>12});
print Dumper($results);
print Dumper($header);
sub process_message{
	my $hash = shift;
	my $emails_app_mongo = shift;
	my $emails_app_redis = shift;
	my $eaid = generateID();
	my $mongo_id = $emails_app_mongo->insert_mail($hash,$eaid);
	my $redis_id = $emails_app_redis->insert_message('id',$eaid);
	return $eaid&&$mongo_id&&$redis_id ? 1 : 0;
}




$emails_app_redis->{redis}->quit;