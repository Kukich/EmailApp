#!/usr/local/bin/perl

use lib "./lib/";
use EmailsAppMongo;
use EmailsAppRedis;
use SMTPClient qw/send_mail/;
use Utils qw/check_filters LoadYamlFile check_params generateID/;
use Try::Tiny;
use Data::Dumper;

#==========init==================================
my $config = LoadYamlFile('email_server.yaml');
my $redis_config = $config->{redis};
my $emails_app_redis = EmailsAppRedis->new($redis_config);
my $mongo_config = $config->{mongo};
my $emails_app_mongo = EmailsAppMongo->new($mongo_config);
$emails_app_mongo->collection($mongo_config->{collection});
$emails_app_redis->check_channel;
$emails_app_redis->create_group;
while(1){
	my $message = [];
	CHECK_MESSAGE:
	$message = $emails_app_redis->check_messages;
#	print Dumper($message);
	if(scalar (@$message) && $message->[0] != 0){
		my $m = {
			id       => $emails_app_redis->get_data($message->[0]->[0]),
			redis_id => $message->[0]->[0],
		};
		process_send_mail($m,$config->{mail},$emails_app_redis,$emails_app_mongo);
		goto CHECK_MESSAGE;
	}
	my $new_messages=[];
	READ_GROUP:
	$new_messages = $emails_app_redis->read_group;
#	print Dumper($new_messages);
	if(scalar (@$new_messages)){
		my $m = {
			id       => $new_messages->[0]->[1]->[0]->[1]->[1],
			redis_id => $new_messages->[0]->[1]->[0]->[0],
		};
		process_send_mail($m,$config->{mail},$emails_app_redis,$emails_app_mongo);
		goto READ_GROUP;
	}
	print "waiting for the new messages\n";
	sleep(5);
}
$emails_app_redis->{redis}->quit;
print  "bye\n";


sub process_send_mail{
	my $m = shift;
	my $mail_config = shift;
	my $emails_app_redis = shift;
	my $emails_app_mongo = shift;
	print "start process_send_mail\n";
	print Dumper($m);
	my $result = $emails_app_mongo->get_mail($m->{id});
	print Dumper($result);
	if($result){
		my $send_mail_status;
		if($result->{sent_status} == 0 && $mail_config->{delivery} == 1){
			print "try to send mail\n";
			$send_mail_status = send_mail($config->{mail},$result->{to},$result->{sender},$result->{subject},$result->{message});
		}else{
			$send_mail_status = 1;
		}
		print "send_mail_status = $send_mail_status\n";
		if($send_mail_status){
			$emails_app_mongo->{collection}->update_one({id=>$m->{id}},{'$set'=>{sent_status=>1}}) if ($result->{sent_status} == 0);
			$emails_app_redis->proccessed_message($m->{redis_id});
		}
	}else{
		$emails_app_redis->proccessed_message($m->{redis_id});
	}
	print "end process_send_mail\n";
}