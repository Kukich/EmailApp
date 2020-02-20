package SMTPClient;

use MIME::Base64;	
use IO::Socket::SSL;		
use Text::Iconv;
use Encode;
use Data::Dumper;
use strict;

use base 'Exporter';
our @EXPORT = qw(send_mail);




sub send_mail{
	my $config = shift;
	my ($to,$sender,$subject,$text) = @_;
	unless(ref $to eq 'ARRAY'){
		$to = [$to];
	}
	print "send_mail start\n";
#	my $socket = IO::Socket::SSL->new($config->{smtp_host});
	my $mailbox = $config->{login};
	my $mailpwd = $config->{password};		
	my $cnv = Text::Iconv->new('UTF8','CP1251');
	my $reply;	
	my $message;	
	#открываем сокет к SMTP-серверу
	my $socket = IO::Socket::SSL->new('smtp.yandex.ru:465');
	defined $socket or die "ERROR: $!\n";
	($reply,$message) = ReadReply($socket);
	if($reply ne 220){print STDERR "Ошибка установки связи = $message\n"; $socket->close(); return 0;}
	$socket->print ("helo lo\n");
	($reply,$message) = ReadReply($socket);
	if( $reply != 250){print STDERR "Ошибка приветствия сервера = $message\n"; $socket->close(); return 0;}
	# проводим авторизацию
	$socket->print("AUTH LOGIN\n");
	# получаем ответ
	($reply,$message) = ReadReply($socket);
	if( $reply ne 334){print STDERR "Ошибка авторизации = $message\n"; $socket->close(); return 0;}
	# кодируем логин-пароль
	$socket->print(encode_base64($mailbox).encode_base64($mailpwd));
	# после авторизации выдается две строчки
	ReadReply($socket);
	($reply,$message) = ReadReply($socket);
	if($reply ne 235){print STDERR "Ошибка авторизации = $message\n"; $socket->close(); return 0;}
	# начинаем транзакцию - даем команду отправки письма
	$socket->print('mail from: '."$mailbox\n");
	($reply,$message) = ReadReply($socket);
	if($reply ne 250){print STDERR "Ошибка в почтовом ящике отправителя = $message\n"; $socket->close(); return 0;}
	# указываем получателя(ей)
	foreach my $mail(@$to){
		$socket->print("rcpt to: $mail\n");
		($reply,$message) = ReadReply($socket);
		if( $reply ne 250){print STDERR "Ошибка в почтовом ящике получателя = $message\n"; $socket->close(); return 0;}
	}
	# теперь начинаем формировать письмо
	$socket->print("data\n");
	($reply,$message) = ReadReply($socket);
	if($reply ne 354){print STDERR "Ошибка при начале формирования письма = $message\n"; $socket->close(); return 0;}
	$subject = encode_base64($cnv->convert($subject));
	$subject =~ s/\n//ig;	# уберем символы перевода строки
	$subject =~ s/\r//ig;	# и возврата каретки, поскольку они все ломают :)
	$subject = '=?Windows-1251?B?'.$subject.'?=';
	# создадим тело письма
	Encode::from_to($text, 'utf-8','windows-1251' );
	my $msg = encode_base64($text);

	# здесь формируем заголовок, минимальная версия
	my $body = "Mime-Version: 1.0\n";
	$body .= "Content-Type: multipart/mixed; boundary=\"-\"\n\n";
	# вставляем тело письма
	$body .= "---\nContent-Type: text/plain;\n\tcharset=\"Windows-1251\"\nContent-Transfer-Encoding: base64\n\n$msg\n";
	# и наконец соберем письмо в одну переменную :) 
	my $mailrcpt = join(',',@$to);
	my $mailmessage = "From:$sender\nTo:$mailrcpt\nSubject:$subject\n$body\n.\n";
	# скинем письмо серверу
	$socket->print($mailmessage);
	# и посмотрим что получилось
	($reply,$message) = ReadReply($socket);
	if( $reply ne 250){print STDERR "Ошибка при отправке письма = $message\n"; $socket->close(); return 0;}
		# если дошли до этого места, значит письмо ушло
	$socket->close();	
	print "send_mail end ok\n";
	return 1;
}
sub ReadReply{
		my $socket = shift;
        my $val = 1;
		my $r;
        while($val eq 1){
                $r = <$socket>;
                $val = $r =~ m/^\d{3}-/g;
        }
        my ($reply,$message) = split(/ /,$r,2);
        return ($reply,$message);
}
1;