package Test2::Harness::Job::Runner::IPC;
use strict;
use warnings;

our $VERSION = '0.001080';

use Test2::Harness::Util qw/open_file write_file local_env/;
use Test2::Harness::Util::IPC qw/run_cmd/;
use Test2::Util qw/pkg_to_file/;

use File::Spec();

sub viable { 1 }

sub find_inc {
    my $class = shift;

    # Find out where Test2::Harness::Run::Worker came from, make sure that is in our workers @INC
    my $inc = $INC{"Test2/Harness/Job/Runner.pm"};
    $inc =~ s{/Test2/Harness/Job/Runner\.pm$}{}g;
    return File::Spec->rel2abs($inc);
}

sub command_file {
    my $class = shift;
    my ($test) = @_;
    return File::Spec->abs2rel($test->job->file);
}

sub command {
    my $class = shift;
    my ($test, $event_dir, $inc) = @_;

    my $job = $test->job;

    return (
        $^X,
        (map { "-I$_" } @$inc),
        $ENV{HARNESS_PERL_SWITCHES} ? $ENV{HARNESS_PERL_SWITCHES} : (),
        @{$job->switches},
        $job->event_uuids ? ('-MTest2::Plugin::UUID') : (),
        $job->mem_usage ? ('-MTest2::Plugin::MemUsage') : (),
        (map { "-M$_" } @{$job->load_import || []}),
        (map { "-m$_" } @{$job->load        || []}),
        $job->use_stream ? ("-MTest2::Formatter::Stream=dir,$event_dir") : (),
        $job->times ? ('-MTest2::Plugin::Times') : (),
        $class->command_file($test),
        @{$job->args},
    );
}

sub run {
    my $class = shift;
    my ($test) = @_;

    my $job = $test->job;

    my ($in_file, $out_file, $err_file, $event_dir) = $test->output_filenames;

    my $out_fh = open_file($out_file, '>');
    my $err_fh = open_file($err_file, '>');

    write_file($in_file, $job->input);
    my $in_fh = open_file($in_file, '<');

    my $env = {
        %{$job->env_vars},
        $job->use_stream
            ? ( T2_FORMATTER => 'Stream',
                T2_STREAM_DIR => $event_dir )
            : (),
    };

    my %seen;
    my @inc = (grep { !$seen{$_}++ } map { File::Spec->rel2abs($_) } @{$job->libs}, $class->find_inc, @INC);

    my $pid;
    local_env $env => sub {
        $pid = run_cmd(
            chdir   => $job->ch_dir,
            command => sub { $class->command($test, $event_dir, \@inc) },
            stdin   => $in_fh,
            stdout  => $out_fh,
            stderr  => $err_fh,
        );
    };

    return ($pid, undef);
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test2::Harness::Job::Runner::IPC - Logic for running a test in a new perl
process.

=head1 DESCRIPTION

=head1 SOURCE

The source code repository for Test2-Harness can be found at
F<http://github.com/Test-More/Test2-Harness/>.

=head1 MAINTAINERS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 AUTHORS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 COPYRIGHT

Copyright 2019 Chad Granum E<lt>exodist7@gmail.comE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://dev.perl.org/licenses/>

=cut
