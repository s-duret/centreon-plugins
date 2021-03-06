#
# Copyright 2015 Centreon (http://www.centreon.com/)
#
# Centreon is a full-fledged industry-strength solution that meets
# the needs in IT infrastructure and application monitoring for
# service performance.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

package database::firebird::mode::iostats;

use base qw(centreon::plugins::mode);

use strict;
use warnings;
use POSIX;

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options);
    bless $self, $class;
    
    $self->{version} = '1.0';
    $options{options}->add_options(arguments =>
                                { 
                                  "warning:s"               => { name => 'warning', },
                                  "critical:s"              => { name => 'critical', },
                                });

    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::init(%options);

    if (($self->{perfdata}->threshold_validate(label => 'warning', value => $self->{option_results}->{warning})) == 0) {
        $self->{output}->add_option_msg(short_msg => "Wrong warning threshold '" . $self->{option_results}->{warning} . "'.");
        $self->{output}->option_exit();
    }
    if (($self->{perfdata}->threshold_validate(label => 'critical', value => $self->{option_results}->{critical})) == 0) {
        $self->{output}->add_option_msg(short_msg => "Wrong critical threshold '" . $self->{option_results}->{critical} . "'.");
        $self->{output}->option_exit();
    }
}

sub run {
    my ($self, %options) = @_;
    # $options{sql} = sqlmode object
    $self->{sql} = $options{sql};

    $self->{sql}->connect();
    
    if (!($self->{sql}->is_version_minimum(version => '1'))) {
        $self->{output}->add_option_msg(short_msg => "Firebird version '" . $self->{sql}->{version} . "' is not supported (need version >= '5.x').");
        $self->{output}->option_exit();
    }
    
    $self->{sql}->query(query => q{SELECT MON$PAGE_READS,MON$PAGE_WRITES  FROM MON$IO_STATS WHERE MON$STAT_GROUP=0;});
    my $result = $self->{sql}->fetchall_arrayref();
    if (!defined($result)) {
        $self->{output}->add_option_msg(short_msg => "Cannot get IO Stats.");
        $self->{output}->option_exit();
    }
    
    my $page_reads = $$result[0][0];
    my $page_writes = $$result[0][1];    
    
    my $exit1 = $self->{perfdata}->threshold_check(value => $page_reads, threshold => [ { label => 'critical', exit_litteral => 'critical' }, { label => 'warning', exit_litteral => 'warning' } ]);
    my $exit2 = $self->{perfdata}->threshold_check(value => $page_writes, threshold => [ { label => 'critical', exit_litteral => 'critical' }, { label => 'warning', exit_litteral => 'warning' } ]);
    my $exit = $self->{output}->get_most_critical(status => [ $exit1, $exit2 ]);
    
    $self->{output}->output_add(severity => $exit,
                                short_msg => sprintf("I/O stats : %d/%d",$page_writes, $page_reads ));
    $self->{output}->perfdata_add(label => 'input', value => $page_writes);
    $self->{output}->perfdata_add(label => 'output', value => $page_reads);

    $self->{output}->display();
    $self->{output}->exit();
}

1;

__END__

=head1 MODE

Check MySQL uptime.

=over 8

=item B<--warning>

Threshold warning.

=item B<--critical>

Threshold critical.

=item B<--seconds>

Display uptime in seconds.

=back

=cut
