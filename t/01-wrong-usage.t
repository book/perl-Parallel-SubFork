#!/usr/bin/perl

use strict;
use warnings;

use POSIX qw(WNOHANG);

use Test::More tests => 16;

BEGIN {
	use_ok('Parallel::SubFork');
	use_ok('Parallel::SubFork::Task');
}

my $PID = $$;
my $MANAGER;
my $TASK;

exit main();


sub main {
	
	# Create a new task
	$MANAGER = Parallel::SubFork->new();
	isa_ok($MANAGER, 'Parallel::SubFork');
	
	# Start a sub task and try to do a wait_for there
	my $task_wait_for_all = $MANAGER->start(\&task_wait_for_all);
	my $task_start = $MANAGER->start(\&task_start);
	$TASK = $MANAGER->start(sub {return 42;});
	my $task_wait_for = $MANAGER->start(\&task_wait_for);

	# Wait for the task to resume
	$MANAGER->wait_for_all();
	
	is($task_wait_for_all->exit_code, 75, "Child process can't call wait_for_all()");
	is($task_start->exit_code, 61, "Child process can't call start()");
	is($TASK->exit_code, 42, "Generic task");
	is($task_wait_for->exit_code, 23, "Child process can't call start()");
	
	
	##
	# Make sure that an argument has to be passed
	assert_exception(
		qr/^First parameter must be a code reference/,
		sub { $MANAGER->start(); }
	);
	
	assert_exception(
		qr/^First parameter must be a code reference/,
		sub { Parallel::SubFork::Task->new(); }
	);
	
	assert_exception(
		qr/^First parameter must be a code reference/,
		sub { Parallel::SubFork::Task->start(); }
	);
	
	return 0;
}


sub assert_exception {
	my ($regexp, $code) = @_;
	is(ref $regexp, 'Regexp', "Expecting a regexp as assert_exception 1st argument");
	is(ref $code, 'CODE', "Expecting a code ref as assert_exception 2nd argument");

	eval {
		$code->();
	};
	if (my $error = $@) {
		ok($error =~ /$regexp/, "Code raised an exception");
		return;
	}
	
	fail("Expected to raise an exception");
}


#
# Test that a task can't call $manager->wait_for_all()
#
sub task_wait_for_all {
	my (@args) = @_;

	my $return = 75;

	++$return unless $$ != $PID;

	eval {
		$MANAGER->wait_for_all();
		++$return;
	};
	if (my $error = $@) {
		my $match = "Process $$ is not the main dispatcher";
		++$return unless $error =~ /^\Q$match\E/;
	}

	return $return;
}


#
# Test that a task can't call $manager->start()
#
sub task_start {
	my (@args) = @_;

	my $return = 61;

	++$return unless $$ != $PID;

	eval {
		$MANAGER->start(
			sub {
				die "***** TEST FAILED ($$ <-> $PID) *****";
			}
		);
		++$return;
	};
	if (my $error = $@) {
		my $match = "Process $$ is not the main dispatcher";
		++$return unless $error =~ /^\Q$match\E/;
	}

	return $return;
}


#
# Test that a task can't call $task->wait_for()
#
sub task_wait_for {
	my (@args) = @_;

	my $return = 23;

	++$return unless $$ != $PID;

	eval {
		$TASK->wait_for();
		++$return;
	};
	if (my $error = $@) {
		my $match = "Only the parent process can wait for the task";
		++$return unless $error =~ /^\Q$match\E/;
	}

	return $return;
}