/* tty;exec disowntty  */
//#include <sys/ioctl.h>
//#include <unistd.h>
//#include <stdio.h>
//#include <limits.h>
//#include <stdlib.h>
//#include <signal.h>

//import std.stdio;
import std.string;
import std.c.stdlib;
import core.thread;
import core.sys.posix.signal;
import core.sys.posix.sys.ioctl;
import core.sys.posix.unistd;
import core.sys.posix.stdio;

//extern(C) void signal(int sig, void function(int) );
//extern(C) void setbuf(FILE * stream, char * buf);
//extern(C) void ioctl(int fd, uint request, int param);

void end(string msg)
{
    perror(msg.toStringz);
    for (;;)
		Thread.sleep(dur!"seconds"(1));
}

alias extern(C) void function(int) sigfn_t;

void main(string args[])
{
  	FILE *tty_name_file;
	if (args.length < 2)
		exit(1);

    string tty_filename = args[1];

	sigfn_t orig;
  	setbuf (stdout, null);
  	orig = signal (SIGHUP, SIG_IGN);
  	if (orig !is SIG_DFL)
    	end ("signal (SIGHUP)");

	printf("%s %s\n", tty_filename.toStringz, ttyname(STDIN_FILENO));
	tty_name_file = fopen(tty_filename.toStringz, "w");
	fprintf(tty_name_file, "%s\n", ttyname(STDIN_FILENO));
	fclose(tty_name_file);
	
	/* Verify we are the sole owner of the tty.  */
	if (ioctl(STDIN_FILENO, TIOCSCTTY, 0) != 0)
    	end ("TIOCSCTTY");

  	printf("%s %s\n", tty_filename.toStringz, ttyname(STDIN_FILENO));
  	tty_name_file = fopen(tty_filename.toStringz, "w");
  	fprintf(tty_name_file, "%s\n", ttyname(STDIN_FILENO));
  	fclose(tty_name_file);

  	/* Disown the tty.  */
  	if (ioctl (STDIN_FILENO, TIOCNOTTY) != 0)
    	end ("TIOCNOTTY");
  	end ("OK, disowned");

	exit(1);
}
