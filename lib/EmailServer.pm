package EmailServer;
use Mojo::Base 'Mojolicious';
use EmailsAppMongo;
use EmailsAppRedis;
use Utils qw/check_filters check_params LoadYamlFile/;
use Try::Tiny;
use JSON;
use Data::Dumper;
use strict;
# This method will run once at server start
sub startup {
  my $self = shift;
  $self->plugin('DefaultHelpers');
  # Load configuration from hash returned by config file
  my $home = Mojo::Home->new;
  my $file = $home."/../email_server.yaml";
  my $config = LoadYamlFile($file);
	
  # Configure the application
  $self->secrets($config->{secrets});

  # Router
  my $r = $self->routes;
  	#==========init==================================
	my $redis_config = $config->{redis};
	my $emails_app_redis = EmailsAppRedis->new($redis_config);
	my $mongo_config = $config->{mongo};
	my $emails_app_mongo = EmailsAppMongo->new($mongo_config);
	my $mail_config = $config->{mail};
	$emails_app_mongo->collection($mongo_config->{collection});
	$self->{emails_app_mongo} = $emails_app_mongo;
	$self->helper(emails_app_mongo =>sub{$emails_app_mongo});
	$self->helper(emails_app_redis =>sub {return $emails_app_redis});
	$self->helper(email_config => sub{return $config});
  # Normal route to controller
   

	$r->add_condition(input_params => sub {
		my ($route, $c ) = @_;
#		print Dumper($c->req->body);
		my $content = from_json($c->req->body,{utf8=>1});
		my @err = check_params($content);
		if(scalar (@err)){
			$c->res->code(400);
			return $c->render(json => {err => \@err});
		}
		$c->stash(INPUT_PARAMS => $content);
		return 1;
	});
	$r->add_condition(input_filters => sub {
		my ($route, $c ) = @_;
		my $params = $c->req->params->to_hash;
		my @err = check_filters($params);
		if(scalar (@err)){
			$c->res->code(400);
			 $c->render(json => {err => \@err});
			 return undef;
		}
		return 1;
	});
	$r->get('/')->to('notifs#welcome');
	$r->get("/notifs/:id/")->to('notifs#get_notif');
	$r->get("/notifs/")->over(input_filters => 4)->to("notifs#get_notifs");
	$r->post('/notifs')->over(input_params => 1)->to("notifs#send_notif");
	$r->route('/docs')->to("notifs#docs");

}

1;
