package EMAIL;
########################################################################
#
# HostingAPI - Ed Toton & Jeremy Kusnetz
#

use strict;
use Net::SMTP;
use MIME::Entity;
use Email::MIME;


# Don't set default values here!
my $last_rs;
my @months;

my $NUMSERVER=10;

BEGIN { # Export functions first because of possible circular dependancies
   use Exporter;
   use vars qw(@ISA $VERSION @EXPORT_OK);

   $VERSION = 2.01;
   @ISA = qw(Exporter);
   @EXPORT_OK = qw(sendSMTP sendMail sendAttachment sendAttachmentMime sendMultipleAttachments sendMultipart sendMultipartOnce);

   $last_rs = '';
   my @months = ('Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec');
}

use lib "/home/bones/perl";
use ATOMS qw(epoch2maildate);

#############################################################################

sub sendMultipartOnce {
	my $email   = shift;
	my $cc      = shift;
	my $bcc     = shift;
	my $fromname= shift;
	my $from    = shift;
	my $subject = shift;
	my $text    = shift;
	my $html    = shift;
	my $mime    = shift;
	my $filename= shift;
	my $attach  = shift;
	my $totalsent = 0;
	my @recips = ();

	my $maildate = epoch2maildate();

	$email =~ s/[\,\;\s]+/\, /g;
	$email =~ s/^[\,\;\s]+//;
	$email =~ s/[\,\;\s]+$//;

	$cc =~ s/[\,\;\s]+/\, /g;
	$cc =~ s/^[\,\;\s]+//;
	$cc =~ s/[\,\;\s]+$//;

	$bcc =~ s/[\,\;\s]+/\, /g;
	$bcc =~ s/^[\,\;\s]+//;
	$bcc =~ s/[\,\;\s]+$//;

	my  @to_list = ();
	my  @cc_list = ();
	my @bcc_list = ();

	foreach my $to (split /[\;\,\s\n\r]+/, $email) {
		push @to_list, $to;
		push @recips, $to;
	}

	foreach my $to (split /[\;\,\s\n\r]+/, $cc) {
		push @cc_list, $to;
		push @recips, $to;
	}

	foreach my $to (split /[\;\,\s\n\r]+/, $bcc) {
		push @bcc_list, $to;
		push @recips, $to;
	}

	my $display_from = "\"$fromname\" <$from>";
	$display_from = $from if (!$fromname);

	my $message = MIME::Entity->build(Type  => 'multipart/alternative',
					Encoding => '-SUGGEST',
					From     => $display_from,
					Subject  => $subject,
					To       => [@to_list],
					Cc       => [@cc_list],
					Date     => $maildate);

	$message->attach(Type    => 'text/plain',
			Encoding => '-SUGGEST',
			Data     => $text) if ($text);

	$message->attach(Type    => 'text/html',
			Encoding => '-SUGGEST',
			Data     => $html) if ($html);

	$message->attach(Type    => $mime,
			Filename => $filename,
			Data     => [$attach]) if ($filename && $attach && $mime);

	$message->attach(Type    => $mime,
			Data     => [$attach]) if (!$filename && $attach && $mime);

	foreach my $to (@recips) {
		my $sent = 0;
		my $tries = 0;
		while (!$sent && ($tries<3)) {
			$sent = sendSMTP($to,$from,$message->stringify);
			$tries++;
		}
	
		$totalsent++ if ($sent);

		my $attachinfo = '';
		$attachinfo = " (\"$filename\", ".length($attach)." bytes, Type: $mime)" if ($filename);

		#my_syslog("EMAIL SENT: ($last_rs) [to: $to] $subject$attachinfo") if ($sent);
		#my_syslog("EMAIL FAILED: [to: $email] $subject$attachinfo") if (!$sent);
	}
	
	return $totalsent;
}



sub sendMultipart {
	my $email   = shift;
	my $fromname= shift;
	my $from    = shift;
	my $subject = shift;
	my $text    = shift;
	my $html    = shift;
	my $mime    = shift;
	my $filename= shift;
	my $attach  = shift;
	my $totalsent = 0;

	my $maildate = epoch2maildate();

	$email =~ s/[\,\;\s]+/\, /g;
	$email =~ s/^[\,\;\s]+//;
	$email =~ s/[\,\;\s]+$//;

	foreach my $to (split /[\;\,\s\n\r]+/, $email) {

		my $message = MIME::Entity->build(Type  => 'multipart/alternative',
						Encoding => '-SUGGEST',
						From   => "\"$fromname\" <$from>",
						Subject  => $subject,
						To       => $to,
						Date     => $maildate);

		$message->attach(Type    => 'text/plain',
				Encoding => '-SUGGEST',
				Data     => $text) if ($text);

		$message->attach(Type    => 'text/html',
				Encoding => '-SUGGEST',
				Data     => $html) if ($html);

		$message->attach(Type    => $mime,
				Filename => $filename,
				Data     => [$attach]) if ($filename && $attach && $mime);
	
		$message->attach(Type    => $mime,
				Data     => [$attach]) if (!$filename && $attach && $mime);
	
		my $sent = 0;
		my $tries = 0;
		while (!$sent && ($tries<3)) {
			$sent = sendSMTP($to,$from,$message->stringify);
			$tries++;
		}
	
		$totalsent++ if ($sent);

		my $attachinfo = '';
		$attachinfo = " (\"$filename\", ".length($attach)." bytes, Type: $mime)" if ($filename);

		#my_syslog("EMAIL SENT: ($last_rs) [to: $to] $subject$attachinfo") if ($sent);
		#my_syslog("EMAIL FAILED: [to: $email] $subject$attachinfo") if (!$sent);
	
	}
	return $totalsent;
}



#############################################################################
#
# sendMultipleAttachments	Send multiple attachments with basic text.
#

sub sendMultipleAttachments {
	my $msgType   = shift;
	my $email     = shift;
	my $fromname  = shift;
	my $from      = shift;
	my $subject   = shift;
	my $text      = shift;
	my $totalsent = 0;
	my @mime      = ();
	my @filename  = ();
	my @filedata  = ();

	while (@_) {		# loop over remaining parameters, which is all file-attachment stuff
		push @mime, shift;
		push @filename, shift;
		push @filedata, shift;
	}

	my $maildate = epoch2maildate();

	$email =~ s/[\,\;\s]+/\, /g;
	$email =~ s/^[\,\;\s]+//;
	$email =~ s/[\,\;\s]+$//;

	foreach my $to (split /[\;\,\s\n\r]+/, $email) {

		my $attachinfo = ' (';

		my $message = MIME::Entity->build(From   => "\"$fromname\" <$from>",
						Subject  => $subject,
						To       => $to,
						Date     => $maildate,
						Type     => $msgType,
						Data     => [$text]);
	
		for (my $i=0; $i<@filename; $i++) {
			$message->attach(Type    => $mime[$i],
					Filename => $filename[$i],
					Data     => [$filedata[$i]]
					);

			$attachinfo .= ",\"$filename[$i]\", ".length($filedata[$i])." bytes, Type: $mime[$i]";
		}

		$attachinfo .= ')';
		$attachinfo =~ s/^\(,/\(/;
	
		my $sent = 0;
		my $tries = 0;
		while (!$sent && ($tries<3)) {
			$sent = sendSMTP($to,$from,$message->stringify);
			$tries++;
		}
	
		$totalsent++ if ($sent);

		#my_syslog("EMAIL SENT: ($last_rs) [to: $to] $subject$attachinfo") if ($sent);
		#my_syslog("EMAIL FAILED: [to: $email] $subject$attachinfo") if (!$sent);
	
	}
	return $totalsent;
}

#############################################################################
#
# sendAttachment	Send an email attachment with basic text
#

sub sendAttachment {
	return sendAttachmentMime('text/html',@_);
}

sub sendAttachmentMime {
	my $msgType = shift;
	my $email   = shift;
	my $fromname= shift;
	my $from    = shift;
	my $subject = shift;
	my $mime    = shift;
	my $filename= shift;
	my $attach  = shift;
	my @msg     = shift;
	my $totalsent = 0;

	my $text = join '', @msg;

	my $maildate = epoch2maildate();

	$email =~ s/[\,\;\s]+/\, /g;
	$email =~ s/^[\,\;\s]+//;
	$email =~ s/[\,\;\s]+$//;

	foreach my $to (split /[\;\,\s\n\r]+/, $email) {

		my $message = MIME::Entity->build(From   => "\"$fromname\" <$from>",
						Subject  => $subject,
						To       => $to,
						Date     => $maildate,
						Type     => $msgType,
						Data     => [$text]);
	
		$message->attach(Type    => $mime,
				Filename => $filename,
				Data     => [$attach]) if ($filename);
	
		$message->attach(Type    => $mime,
				Data     => [$attach]) if (!$filename);
	
		my $sent = 0;
		my $tries = 0;
		while (!$sent && ($tries<3)) {
			$sent = sendSMTP($to,$from,$message->stringify);
			$tries++;
		}
	
		$totalsent++ if ($sent);

		my $attachinfo = '';
		$attachinfo = " (\"$filename\", ".length($attach)." bytes, Type: $mime)" if ($filename);

		#my_syslog("EMAIL SENT: ($last_rs) [to: $to] $subject$attachinfo") if ($sent);
		#my_syslog("EMAIL FAILED: [to: $email] $subject$attachinfo") if (!$sent);
	
	}
	return $totalsent;
}


#############################################################################
#
# sendMail	Send an email message through a random realserver, with
#		multiple retries for failure.
#
#	sendMail($Recipients,$FromAddress,$Subject,@MessageText);

sub sendMail {
	my $email   = shift;
	my $from    = shift;
	my $subject = shift;
	my @msg     = shift;

	my $maildate = epoch2maildate();

	$email =~ s/[\,\;\s]+/\, /g;
	$email =~ s/^[\,\;\s]+//;
	$email =~ s/[\,\;\s]+$//;

	if (!$email) {
		warn "Must supply email addresses\n";
		return 0;
	}

	my @header = ();

	push @header, "Subject: $subject\n";
	push @header, "To: $email\nFrom: $from\n";
	push @header, "Date: $maildate\n";
	push @header, "\n";

	my $sent = 0;
	my $tries = 0;
	while (!$sent && ($tries<3)) {
		$sent = sendSMTP($email,$from,@header,@msg);
		$tries++;
	}

	#my_syslog("EMAIL SENT: ($last_rs) [to: $email] $subject") if ($sent);
	#my_syslog("EMAIL FAILED: [to: $email] $subject") if (!$sent);

	return $sent;
}

sub sendSMTP() {
	my ($to,$from,@msg) = @_;
	my $rs = int(rand($NUMSERVER)+1);
	$from =~ s/.*<(.*)>/$1/g;
	$last_rs = "stsakai$rs:25";

	my @tos = split /[\,\;\s]+/, $to;

#ED (2012-05-22):
	$last_rs = '127.0.0.1';

	my $remote = Net::SMTP->new($last_rs,
				Hello => "reaper.necrobones.net",
				Port => 25,
				Timeout => 10,
				) or return 0;

	my $text = join '', @msg;

	if ($remote) {
		$remote->mail($from) or return 0;
		foreach my $t (@tos) {
			$remote->to($t) or return 0;
		}
		$remote->data() or return 0;
		$remote->datasend($text) or return 0;
		$remote->dataend or return 0;
		$remote->quit;
		my_syslog("Mail sent to '$to'");
		return 1;
	} else {
		my_syslog("SMTP/$last_rs: Failed to send mail to '$to'");
		return 0;
	}
}

sub my_syslog {
	#warn @_;
}


#############################################################################
#############################################################################
#############################################################################
#############################################################################

1;


