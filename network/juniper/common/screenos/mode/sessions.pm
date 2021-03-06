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

package network::juniper::common::screenos::mode::sessions;

use base qw(centreon::plugins::mode);

use strict;
use warnings;

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
    # $options{snmp} = snmp object
    $self->{snmp} = $options{snmp};
    
    my $oid_nsResSessAllocate = '.1.3.6.1.4.1.3224.16.3.2.0';
    my $oid_nsResSessMaxium = '.1.3.6.1.4.1.3224.16.3.3.0';
    
    my $result = $self->{snmp}->get_leef(oids => [$oid_nsResSessAllocate, $oid_nsResSessMaxium], nothing_quit => 1);
    
    my $spu_done = 0;
    my $cp_total = $result->{$oid_nsResSessMaxium};
    my $cp_used = $result->{$oid_nsResSessAllocate};
        
    my $prct_used = $cp_used * 100 / $cp_total;
    
    $spu_done = 1;
    my $exit_code = $self->{perfdata}->threshold_check(value => $prct_used, 
                            threshold => [ { label => 'critical', 'exit_litteral' => 'critical' }, { label => 'warning', exit_litteral => 'warning' } ]);
    $self->{output}->output_add(severity => $exit_code,
                                short_msg => sprintf("%.2f%% of the sessions limit reached (%d of max. %d)", 
                                    $prct_used, $cp_used, $cp_total));
    $self->{output}->perfdata_add(label => 'sessions',
                                  value => $cp_used,
                                  warning => $self->{perfdata}->get_perfdata_for_output(label => 'warning', total => $cp_total, cast_int => 1),
                                  critical => $self->{perfdata}->get_perfdata_for_output(label => 'critical', total => $cp_total, cast_int => 1),
                                  min => 0, max => $cp_total);

    if ($spu_done == 0) {
        $self->{output}->add_option_msg(short_msg => "Cannot check sessions usage (no total values).");
        $self->{output}->option_exit();
    }
    
    $self->{output}->display();
    $self->{output}->exit();
}

1;

__END__

=head1 MODE

Check Juniper sessions usage (NETSCREEN-RESOURCE-MIB).

=over 8

=item B<--warning>

Threshold warning in percent.

=item B<--critical>

Threshold critical in percent.

=back

=cut
