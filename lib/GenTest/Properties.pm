# Copyright (C) 2009-2010 Sun Microsystems, Inc. All rights reserved.
# Use is subject to license terms.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301
# USA

## Handling of config properties and options
## 
## default: Default values
## options: The hashgenerated by Getoptions
## required: required properties
## legal: additional legal properties. The final set of legal
##        properties is the union between default, options, required
##        and legal. 
## legal and required is not (yet) recursive defined.
##
## Usage:
## my $options = {}
## GetOptions($options,'config=s'................);
## my $config=GenTest::Properties->new(options=>$options......);

##
package GenTest::Properties;

@ISA = qw(GenTest);

use strict;
use Carp;
use GenTest;
use GenTest::Constants;

use Data::Dumper;

use constant PROPS_NAME => 0;
use constant PROPS_DEFAULTS => 1; ## Default values
use constant PROPS_OPTIONS => 2;  ## Legal options to check for
use constant PROPS_HELP => 3;     ## Help text
use constant PROPS_LEGAL => 4;    ## List of legal properies
use constant PROPS_LEGAL_HASH => 5; ## Hash of legal propertis
use constant PROPS_REQUIRED => 6; ## Required properties
use constant PROPS_PROPS => 7;    ## the actual properties

1;

##
## AUTOLOAD function intercepts all calls to undefined methods. Use
## (if defined) PROPS_LEGAL_HASH to decide if the wanted property is
## legal. All intercpeted method calls will return
## $self->[PROPS_PROPS]->{$name}

sub AUTOLOAD {
    my ($self,$arg) = @_;
    my $name = our $AUTOLOAD;
    $name =~ s/.*:://;
    
    ## Avoid catching DESTRY et.al. (no intercepted calls to methods
    ## starting with an uppercase letter)
    return unless $name =~ /[^A-Z]/;
    
    if (defined $self->[PROPS_LEGAL_HASH]) {
        croak("Illegal property '$name' caught by AUTOLOAD ") 
            if not $self->[PROPS_LEGAL_HASH]->{$name};
    }
    
    $self->[PROPS_PROPS]->{$name} = $arg if defined $arg;
    return $self->[PROPS_PROPS]->{$name};
}

## Constructor

sub new {
    my $class = shift;
    
	my $props = $class->SUPER::new({
	    'name' => PROPS_NAME,
	    'defaults'	=> PROPS_DEFAULTS,
	    'required'	=> PROPS_REQUIRED,
	    'options' => PROPS_OPTIONS,
	    'legal' => PROPS_LEGAL,
	    'help' => PROPS_HELP ## disabled since I get weird warning....
       }, @_);
    
    ## List of legal properties, if no such list, all properties are
    ## legal. The PROPS_LEGAL_HASH becomes the union of PROPS_LEGAL,
    ## PROPS_REQURED, PROPS_OPTIONS (specified on command line and
    ## decided from argument to getoptions) and PROPS_DEFAULTS

    if (defined $props->[PROPS_LEGAL]) {
        foreach my $legal (@{$props->[PROPS_LEGAL]}) {
            $props->[PROPS_LEGAL_HASH]->{$legal}=1;
        }
    }
    
    if (defined $props->[PROPS_REQUIRED]) {
        foreach my $legal (@{$props->[PROPS_REQUIRED]}) {
            $props->[PROPS_LEGAL_HASH]->{$legal}=1;
        }
    }
    
    if (defined $props->[PROPS_OPTIONS]) {
        foreach my $legal (keys %{$props->[PROPS_OPTIONS]}) {
            $props->[PROPS_LEGAL_HASH]->{$legal}=1;
        }
    }
    if (defined $props->[PROPS_DEFAULTS]) {
        foreach my $legal (keys %{$props->[PROPS_DEFAULTS]}) {
            $props->[PROPS_LEGAL_HASH]->{$legal}=1;
        }
    }
    

    ## Pick up defaults
    
    my $defaults = $props->[PROPS_DEFAULTS];
    $defaults = {} if not defined $defaults;
    
    ## Pick op command line uptions
    
    my $from_cli = $props->[PROPS_OPTIONS];
    $from_cli = {} if not defined $from_cli;
    
    ## Pick up settings from config file if present

    my $from_file = {};
    
    if ($from_cli->{config}) {
        $from_file = _readProps($from_cli->{config});
    }
    
    ## Calculate settings.
    ## 1: Let defaults be overridden by configfile
    $props->[PROPS_PROPS] = _mergeProps($defaults, $from_file);
    ## 2: Let the command line options override the mege of the two
    ## above
    $props->[PROPS_PROPS] = _mergeProps($props->[PROPS_PROPS], $from_cli);
    
    ## Check for illegal properties
    ## 
    my @illegal;
    if (defined $props->[PROPS_LEGAL_HASH]) {
        foreach my $p (keys %{$props->[PROPS_PROPS]}) {
            if (not exists $props->[PROPS_LEGAL_HASH]->{$p}) {
                push(@illegal,$p);
            }
        }
    }
    ## Check if all required properties are set.
    my @missing;
    if (defined $props->[PROPS_REQUIRED]) {
        foreach my $p (@{$props->[PROPS_REQUIRED]}) {
            push (@missing, $p) if not exists $props->[PROPS_PROPS]->{$p};
        }
    }
    
    my $message;
    $message .= "The following properties are not legal: ".
        join(", ", map {"'--".$_."'"} sort @illegal). ". " if $#illegal >= 0;

    $message .= "The following required properties  are missing: ".
        join(", ", map {"'--".$_."'"} sort @missing). ". " if $#missing >= 0;

    if (defined $message) {
        $props->_help();
        croak($message);
    }
    
    return $props;
}


## Basic set/get method. Note that $x->property('string') is the same
## as $x->string and that $x->property('string', value) is the same as
## $x->string(value). Useful for propertys that can't be perl
## subroutine names.

sub property {
    my ($self, $name, $arg) = @_;

    if (defined $self->[PROPS_LEGAL_HASH]) {
        croak("Illegal property '$name' caught by AUTOLOAD ") 
            if not $self->[PROPS_LEGAL_HASH]->{$name};
    }
    
    $self->[PROPS_PROPS]->{$name} = $arg if defined $arg;
    return $self->[PROPS_PROPS]->{$name};
    
}
## Read properties from a given file
sub _readProps {
    my ($file) = @_;
    open(PFILE, $file) or die "Unable read properties file '$file': $!";
    read(PFILE, my $propfile, -s $file);
    close PFILE;
    my $props = eval($propfile);
    croak "Unable to load $file: $@" if $@;
    return $props;
}

## Merge properties recursively
sub _mergeProps {
    my ($a,$b) = @_;
    
    # First recursively deal with hashes
    my $mergedHashes = {};
    foreach my $h (keys %$a) {
        if (UNIVERSAL::isa($a->{$h},"HASH")) {
            if (defined $b->{$h}) {
                $mergedHashes->{$h} = _mergeProps($a->{$h},$b->{$h});
            }
        }
    }
    # The merge
    my $result = {%$a, %$b};
    $result = {%$result,  %$mergedHashes};
    return $result;
}

sub printHelp {
    $_[0]->_help;
}

## Global print method
sub printProps {
    my ($self) = @_;
    _printProps($self->[PROPS_PROPS]);
}

## Internal print method
sub _printProps {
    my ($props,$indent) = @_;
    $indent = 1 if not defined $indent;
    my $x = join(" ", map {undef} (1..$indent*3));
    foreach my $p (sort keys %$props) {
        if (UNIVERSAL::isa($props->{$p},"HASH")) {
            say ($x .$p." => ");
            _printProps($props->{$p}, $indent+1);
	} elsif  (UNIVERSAL::isa($props->{$p},"ARRAY")) {
        say ($x .$p." => ['".join("', '",@{$props->{$p}})."']");
        } else {
            say ($x.$p." => ".$props->{$p});
        }
    }
}

## Remove proerties set to defined
sub _purgeProps {
    my ($props) = @_;
    my $purged = {};
    foreach my $key (keys %$props) {
        $purged->{$key} = $props->{$key} if defined $props->{$key};
    }
    return $purged;
}

## Generate a option list from a hash. The hash may be tha name of a
## property. The prefix may typically be '--' or '--mysqld=--' for
## Mysql and friends use.
sub genOpt {
    my ($self, $prefix, $options) = @_;

    my $hash;
    if (UNIVERSAL::isa($options,"HASH")) {
        $hash = $options;
    } else {
        $hash = $self->$options;
    }
    
    return join(' ', map {$prefix.$_.(defined $hash->{$_}?
                                      ($hash->{$_} eq ''?
                                       '':'='.$hash->{$_}):'')} keys %$hash);
}

## Collect all or specified non-hash/array options into new option string where
## options are separated by a single space.
## If an array of strings is passed as second argument, only options specified
## in the array will be included.
## If such an array is omitted, all top-level options will be included.
## A prefix is added to each option, similar to sub genOpt.
sub collectOpt {
    # @include is an array specifying property keys to include.
    # If such a list is not provided, all non-complex properties are included.
    my ($self, $prefix, @include) = @_;
    my $props = $self->[PROPS_PROPS];       # all properties (options)
    my @opts;                               # properties (options) to collect

    if (@include) {
        foreach my $key (@include) {
            if (exists $props->{$key}) {
                if (UNIVERSAL::isa($props->{$key}, "HASH")) {
                } elsif (UNIVERSAL::isa($props->{$key}, "ARRAY")) {
                } else {
                    if (defined $props->{$key} and $props->{$key} ne '') {
                        push(@opts, $prefix.$key.'='.$props->{$key});
                    } else {
                        push(@opts, $prefix.$key);
                    }
                }
            }
        }
    } else {
        # No list of options to include was specified.
        # Inlcude all top-level options.
        foreach my $key (keys %$props) {
            if (UNIVERSAL::isa($props->{$key},"HASH")) {
            } elsif  (UNIVERSAL::isa($props->{$key},"ARRAY")) {
            } else {
            if (defined $props->{$key} and $props->{$key} ne '') {
                    push(@opts, $prefix.$key.'='.$props->{$key});
                } else {
                    push(@opts, $prefix.$key);
                }
            }
        }
    }
    
    return join(' ',@opts);
}

## Help routine!
sub _help {
    my ($self) = @_;

    if (defined $self->[PROPS_HELP]) {
        if (UNIVERSAL::isa($self->[PROPS_HELP],"CODE")) {
            ## Help routine provided
            &{$self->[PROPS_HELP]};
        } else {
            ## Help text provided
            print $self->[PROPS_HELP]."\n";
        }
    } else {
        ## Generic help (not very helpful, but better than nothing).
        print "$0 - Legal properties/options:\n";
        my $required = {map {$_=>1} @{$self->[PROPS_REQUIRED]}};
        foreach my $k (sort keys %{$self->[PROPS_LEGAL_HASH]}) {
            ## Required, command line options etc should be marked.
            print "    --$k ".(defined $required->{$k}?"(required)":"").",\n";
        }
    }
}

1;
