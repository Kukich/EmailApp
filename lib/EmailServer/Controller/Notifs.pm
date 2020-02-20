package EmailServer::Controller::Notifs;
use Mojo::Base 'Mojolicious::Controller';
use Data::Dumper;
use Utils qw/generateID/;
# This action will render a template
sub welcome {
  my $self = shift;

  # Render template "example/welcome.html.ep" with message
  $self->render(msg => 'Welcome to the Mojolicious real-time web framework!');
}

sub docs {
  my $self = shift;

  # Render template "example/welcome.html.ep" with message
  $self->redirect_to("/docs.html");
}

sub get_notif{
	my $c = shift;
	use Encode;
	my $id = $c->stash('id');
	print Dumper($c->email_config);
	print $id."\n";
	$c->res->code(200);
	my $results = $c->emails_app_mongo->get_mail($id);
	print Dumper($results);
	print utf8::is_utf8($results->{message})."\n";
	$results->{message} = utf8::is_utf8($results->{message}) ? Encode::decode('utf8',$results->{message}) : $results->{message};
	$c->render(json=>$results);
}

sub get_notifs{
	my $c = shift;
	my ($result,$headers) = $c->emails_app_mongo->get_mails({
		per_page => $c->req->param("per_page") || $c->email_config->{per_page},
		page=>$c->req->param("page") || $c->email_config->{page}
	});
	foreach my $key(keys %$headers){
		$c->res->headers->header($key => $headers->{$key});
	}
	$c->res->code(200);
	$c->render(json=>$result);
}

sub send_notif{
	my $c = shift;
	my $params = $c->stash('INPUT_PARAMS');
	print Dumper($params);
	my $eaid = generateID();
	print Dumper($params);
	my $mongo_id = $c->emails_app_mongo->insert_mail($params,$eaid);
	my $redis_id = $c->emails_app_redis->insert_message('id',$eaid);
	$c->res->code(200);
	$c->render(json=>{id=>$eaid});
}

1;
