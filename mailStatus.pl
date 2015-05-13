#!/usr/bin/perl -w 

use strict; 

require Net::SMTP;

my $toAddress = shift || die "No to address specified.\n"; 
my $fromAddress = shift || die "No from address specified.\n"; 
my $subject = shift || die "No subject specified.\n"; 
my $message = shift || die "No message specified.\n"; 

#Create a new object with 'new'.
my $smtp = Net::SMTP->new("smtp.uu.se");
#Send the MAIL command to the server.
$smtp->mail($fromAddress);
#Send the server the 'Mail To' address.
$smtp->to($toAddress);
#Start the message.
$smtp->data();
#Send the message.
$smtp->datasend("From: $fromAddress\n");
$smtp->datasend("To: $toAddress\n");
$smtp->datasend("Subject: [Sisyphus] [Local Processing] $subject\n");
$smtp->datasend("MIME-Version: 1.0\n");
$smtp->datasend("Content-Type: text/html; charset=us-ascii\n");
$smtp->datasend("\n");
$smtp->datasend("$message\n\n");
#End the message.
$smtp->dataend();
#Close the connection to your server.
$smtp->quit();
