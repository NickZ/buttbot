#!/usr/bin/perl 
use strict;
use warnings;

use Butts qw(buttify);
use IO::Socket;

## globals
use vars qw/$sock %CONF %results $hyp/;
$|=1;

$CONF{file} = shift;
if (not $CONF{file}) {
  $CONF{file}=$0;
  $CONF{file}=~s/\.pl$/\.conf/i;
}

&readconf();

$sock=&connect($CONF{server},$CONF{port});
&error("socket: $! $@") if ($sock eq "");

&send("NICK $CONF{nick}");
&send("USER $CONF{ident} 0 * :$CONF{gecos}");

&forks() if (not $CONF{debug});;

my ($auth, @buffer) ;
$auth ="";
@buffer=();
my ($from,$command,@data);
#list of friends (people who get buttified more often) and enemies (people who dont get butted.)
my (%friends, %enemies);
#frequency that normal people and friends get butted
my ($normalfrequency, $friendfrequency);
#last thing said by someone in the channel
my (@previousdata);
my ($previouschannel);
my (@channels);
my ($starttime);
my (%linestotal);
my (%timeoflastbutting);
my ($fullstring);
my $graceperiod = 240;
#pre-setting frequencies
$friendfrequency = 37;
$normalfrequency = 51;

#remove whitespace!
$CONF{channel} =~ s/\s+//;

#add friends from conf file
if (exists $CONF{friends})
{
    @_ = split(/s*,s*/,$CONF{friends});
    foreach $_ (@_)
    {
	$friends{$_} = 1;
    }
}

#add enemies from conf file
if (exists $CONF{enemies})
{
    @_ = split(/s*,s*/,$CONF{enemies});
    foreach $_ (@_)
    {
	$enemies{$_} = 1;
    }
}


#main execution loop
while (1) {
  #check for errors.
  &error("main: $! $@") if (($! ne "" ) || ($@ ne ""));
  #Otherwise move through the buffer.
  @buffer=split(/\n/,&gets());
  
  foreach my $thing (@buffer) {
      print "$thing\n";
      $fullstring = $thing;
      #putting the message from $thing into a full string to preserve the whitespace, just in case.
      $fullstring =~ s/(.*?)\s+(.*?)\s+(.*)/$3/;
   ($from,$command,@data)=split(/\s+/,$thing);

   $from ||= '';
   $command ||= '';
   #if server pings, ping back.
   if ($from eq "PING") {
	   if ($command=~/^:\d+$/) {
	   		&send("PONG $command");
	   } else {
	  	 &send("PONG :$CONF{nick}");
	   }	   
   }
   
   &error("from server: @data") if ($from eq "ERROR");
 
  #If buttbot has successfully connected to the server, join a channel.
   if ($command eq "001") {
      &send("MODE $CONF{nick} -x"); # hiding hostnames is for wimps.
     if (defined $CONF{channel})
	{
		&send("JOIN $CONF{channel}") ;
		$starttime = time;
		#&send("PRIVMSG $CONF{channel} : BUTTING SYSTEMS ONLINE!");
	}

     if (defined $CONF{nickpass})
	{
		&send("NICKSERV :identify $CONF{nickpass}");
	}
   } 
	#otherwise, if it's a message
	elsif ($command eq "PRIVMSG") {
	#get destination of message
        my $to=shift(@data);
	#get first word of message (might be command)
        my $sub=shift(@data);
	## remove preceding ':'
	$sub=~s/^://;

	##if a user private messages the bot...
	if ($to eq $CONF{nick})
	{
		$to = $from;
		$to =~ s/^:(.*)!.*$/$1/;
		#If the command is !butt, buttify message.
		if ($sub eq "!butt" and @data >0 ) 
		{
	     		 if (($data[0] !~ /^!/) && ($data[0] !~ /^cout/)) 
			{
				  &send("PRIVMSG $to :".join(" ",&buttify(@data)));
			}
		}
		
			#!help helps a brotha out, yo
			if ($sub eq "!help")
			{
			    &send("PRIVMSG $to : Buttbot is a butting robot of the future. Use !butt <message> to buttify a message.");
			}

		##if the first word in the string is equal to the password, set the user to be the admin
		if ($sub eq $CONF{pass}) {
		$auth=$from;
		}

		##ADMIN FUNCTIONS
		 if ($auth eq $from)  {

		##if the first word is "!quote", send the string that follows to the server
		## e.g. "!quote PRIVMSG #testing : HELLO" prints out "HELLO" to #testing
			if ($sub eq "!quote" and @data >0 )
			{
				&send(@data) ;
			}
		##!echo #channel spits out whatever to the channel
			elsif ($sub eq "!echo" and @data >1 )
			{
			    $_ = shift(@data);
			    
				&send("PRIVMSG $_ :".join(" ",@data));
			}
		##!echobutt #channel spits out whatever to the channel, but will buttify it
			elsif ($sub eq "!echobutt" and @data >1 )
			{
			    $_ = shift(@data);
			   
				&send("PRIVMSG $_ :".join(" ",&buttify(@data)));
			}
		#!boom spits out whatever to every channel
			elsif ($sub eq "!boom" and @data > 0)
			{
			    &send("PRIVMSG $CONF{channel} :".join(" ",@data));
			}
		#duh
			elsif ($sub eq "!boombutt" and @data > 0)
			{
			    &send("PRIVMSG $CONF{channel} :".join(" ",&buttify(@data)))
			}
		##!normfreq changes the frequency the normal people get butted
			elsif ($sub eq "!normfreq" and @data >0 )
			{
				$normalfrequency = $data[0];
				print("Normal Frequency changed to $normalfrequency");
			}
		##!friendfreq changes the frequency the friends get butted
			elsif ($sub eq "!friendfreq" and @data >0 )
			{
				$friendfrequency = $data[0];
				print("Friend Frequency changed to $friendfrequency");
			}
		##!addfriend adds someone to the friend list. 
			elsif ($sub eq "!addfriend" and @data >0 )
			{
			    $friends{$data[0]} = 1;
				printf("Friends:\n");
			        foreach (sort keys %friends)
				{
					printf("$_\n");
				}
				if (@data >1)
				{
					if ($data[1] eq "loud")
					{
						&send("PRIVMSG $CONF{channel} : $data[0], you're my BFF :)");
					}
					else
					{
					       &send("PRIVMSG $data[1] : $data[0], you're my BFF :)");
					}
				}
			}
		##!remfriend removes someone from the friend list
			elsif ($sub eq "!remfriend" and @data >0 )
			{
				delete $friends{$data[0]};
				printf("Friends:\n");
				foreach (sort keys %friends)
				{
					printf("$_\n");
				}
				if (@data >1)
				{
					if ($data[1] eq "loud")
					{
						&send("PRIVMSG $CONF{channel} :  $data[0],  I'm breaking up with you :(");
					}
					else
					{
						&send("PRIVMSG $data[1] :  $data[0],  I'm breaking up with you :(");
					}
				}
			}
		##!addenemy adds someone to the enemy list
			elsif ($sub eq "!addenemy" and @data >0 )
			{
			    $enemies{$data[0]} = 1;
				printf("Enemies:\n");
				foreach (sort keys %enemies)
				{
					printf("$_\n");
				}
				if (@data >1)
				{
					if ($data[1] eq "loud")
					{
						&send("PRIVMSG $CONF{channel} : SHUN DESIGNATED: $data[0]");
					}
					else
					{
					    &send("PRIVMSG $data[1] :  SHUN DESIGNATED: $data[0]");
					}
				}
			}
		##!remenemy removes someone from the enemy list
			elsif ($sub eq "!remenemy" and @data >0 )
			{
			        delete $enemies{$data[0]};
				printf("Enemies:\n");
				foreach (sort keys %enemies)
				{
					printf("$_\n");
				}
				if (@data >1)
				{
					if ($data[1] eq "loud")
					{
						&send("PRIVMSG $CONF{channel} : SHUN REMOVED: $data[0]");
					}
					else
					{
					    	&send("PRIVMSG $data[1] : SHUN REMOVED: $data[0]");
					}
				}
			}
		##!buttnow will buttify the previous message said in the channel.
			elsif ($sub eq "!buttnow" and @previousdata > 0)
			{
				if (($previousdata[0] !~ /^!/) && ($previousdata[0] !~ /^cout/)) 
				{
			  		&send("PRIVMSG $previouschannel :".join(" ",&buttify(@previousdata)));
				}
			}
			elsif ($sub eq "!join" and @data > 0)
			{
			    $CONF{channel} = $CONF{channel}.",";
			    $CONF{channel} = $CONF{channel}.$data[0];
			    &send("JOIN $data[0]");
			}
			elsif ($sub eq "!leave" and @data > 0)
			{
			    $CONF{channel} =~ s/$data[0]//;
			    &send("PART $data[0]");
			}
		
			
		}
	}
	#if messages come from channel, start buttifying
      elsif ($to =~ /^#/ )  {
	  
	  my $sender = $from;
	  $sender =~ s/^:(.*)!.*$/$1/;
	  if (exists $linestotal{$to})
	  {
	  $linestotal{$to}++;
	  }
	  else
	  {
	      $linestotal{$to} = 1;
	  }
		##ignores statements from cout and users containing the word "bot"
              if (($from !~/^:cout/) && ($from !~/^:[^!]*bot[^!]*!/i)) {
	      if ($sub !~ /^!/) {
			my $rnd = 1;
			unshift (@data,$sub);
			if (@data > 1) {
				#if it's a enemy, don't buttify message. If friend, buttify message more often.
			    $rnd = tobuttornottobutt($sender);
				
			}
			  
			#if the random number is 0, buttify that data
			if ($rnd ==0) {
			  
			  $timeoflastbutting{$to} = time;
			  sleep(@data*0.2 + 1);
			  &send("PRIVMSG $to :".join(" ",&buttify(@data)));
			}
			#store this for later butting
			else
			{
				@previousdata = @data;
				$previouschannel = $to;
			}
	      } elsif ($sub eq "!butt" and @data >0 ) {
	          if (($data[0] !~ /^!/) && ($data[0] !~ /^cout/)) {
		  &send("PRIVMSG $to :".join(" ",&buttify(@data)));
	      }
	      }
	 }
	 }
   }
 }
}


#for future determining of butting
sub tobuttornottobutt
{
    my($rnd, $sender);
    $sender = shift;
    if (exists $enemies{$sender}) {
				$rnd = 1;
				}
				elsif (exists $friends{$sender}) { 
				$rnd = int(rand(int($friendfrequency)));
				} 
				else {
				$rnd = int(rand(int($normalfrequency)));
				}
    return $rnd;
}
sub connect {
  my ($remote_host,$remote_port,$local_host)=(shift,shift,shift);
  my $socket=IO::Socket::INET->new( PeerAddr => $remote_host,
                                 PeerPort => $remote_port,
                                 proto    => "tcp",
                                 Type     => SOCK_STREAM,
                                 Timeout  => 10
                                 );
  return $socket;
}

sub gets {
  my $data = "";
  $sock->recv($data,1024) ;
#or &error("get: $! $@");
  return $data;
}
sub send {
  my ($text) = join(" ",@_);
  $text.="\n";
  $sock->send($text);
}

sub forks {
my $spoon=fork();
  if (defined $spoon) {
    if ($spoon==0) {
    return;
    } else {
    print "exiting, child pid=$spoon\n";
    exit;
    }
  } else {
    &error("fork: $! $@");
  }
}

sub error {
    print "\nerror: @_\n";
    exit;
}

sub readconf {
  our %CONF;
  my ($conffile)=@_;
  open(CONF,"$CONF{file}") or &error("readconf: cannot open $CONF{file}");
  while (my $line=<CONF>) {
    if (substr($line,0,1) ne "#") {
     if ($line =~/^\s*([^\s]+)\s*=\s*(.+)$/) {
        $CONF{lc($1)}=$2;
      }
     }
  }   
  close(CONF);
}
