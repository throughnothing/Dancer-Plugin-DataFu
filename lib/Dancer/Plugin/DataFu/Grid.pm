# ABSTRACT: Dancer HTML Grid/Table renderer
package Dancer::Plugin::DataFu::Grid;

use warnings;
use 5.008001;
use Template;
use Template::Stash;
use Array::Unique;
use Dancer::FileUtils;
use Hash::Merge qw/merge/;
use Oogly qw/:all !error/;
use Dancer qw/:syntax !error/;
use File::ShareDir qw/:ALL/;

{
    no warnings 'redefine';
    sub new {
        my $class    = shift;
        my $settings = shift;
        my $profiles = $settings->{grid}->{profiles}
          || die 'No grid profiles are configured in the config file';
        my @profiles =
          glob path( dirname($0), ( split /[\\\/]/, $profiles ), '*.pl' );
        my $self   = {};
        my $fields = {};
    
        foreach my $profile (@profiles) {
            next unless $profile;

            die "No such profile: $profile\n"   unless -f $profile;
            die "Can't read profile $profile\n" unless -r _;

            my ($profile_name) = $profile =~ /[\\\/]([\w\.]+)\.pl/;
            die "Could not generate a profile name for profile $profile"
              unless $profile_name;

            $fields->{$profile_name} = do $profile;
            die "Input profiles didn't return a hash ref: $@\n"
              unless ref $fields->{$profile_name} eq "HASH";
        }
    
        #my $globule = {};
        #my $params  = params;
        #foreach my $key ( keys %{$fields} ) {
        #    foreach my $field ( keys %{ $fields->{$key} } ) {
        #        $globule->{"$key.$field"} = $fields->{$key}->{$field};
        #    }
        #}
        
        $self->{profile} = $fields;
    
        my $template_directory =
          $settings->{grid}->{templates}
          ? path( dirname($0), $settings->{grid}->{templates} )
          : module_dir('Dancer::Plugin::DataFu') . "/elements/";
    
        $self->{profiles}  = \@profiles;
        $self->{templates} = { directory => $template_directory };
    
        foreach my $tmpl ( glob path $template_directory, '*.tt' ) {
            my ( $file, $name ) = $tmpl =~ /.*[\\\/]((\w+)\.tt)/;
            $self->{templates}->{$name} = $file;
        }
    
        die "No TT HTML tempxlates where found under $template_directory"
          if keys %{ $self->{templates} } <= 1;
    
        bless $self, $class;
        return $self;
    }
    
    sub template {
        my ( $self, $element, $path ) = @_;
        return $self->{data}->{templates}->{$element} = $path;
    }
}

sub render {
    my ( $self, $name, $dataset, $profile, @options ) = @_;
    my $configuration = {};
       $profile = $self->{profile}->{$profile} if $profile;;
    
    # check for grid template vars
    if ( ref( $options[@options] ) eq "HASH" ) {
        $configuration = pop @options;
    }

    my $tempro = sub {
        my ($file, $args) = @_;
        my $template    = Template->new(
            INTERPOLATE => 1,
            EVAL_PERL   => 1,
            ABSOLUTE    => 1,
            ANYCASE     => 1
        );
        
        my $data = undef;
        
        $template->process( $file, $args, \$data );
        
        return $data;
    };

    my $counter    = 0;
    my @grid_table = ();
    my @grid_parts = ();
    my $tvars      = {
        name    => $name,
        prof    => $profile,
        vars    => $configuration
    };
    
    # headers
    for (my $i = 0; $i < @{$profile->{columns}}; $i++){
        $tvars->{colm} = $profile->{columns}->[$i];
        $grid_parts[$counter++] = $tempro->($self->temppath('thead.tt'), $tvars);
    }
    
    push @grid_table, $tempro->($self->temppath('trow.tt'), {
        content => join( "\n", @grid_parts ),
    });
    
    @grid_parts = ();
    $counter = 0;
    
    # data rows
    foreach my $row (@{$dataset}) {
        
        for (my $i = 0; $i < @{$profile->{columns}}; $i++) {
            
            $profile->{columns}->[$i]->{data}
                =  $row->{$profile->{columns}->[$i]->{bindto}}
                if defined $profile->{columns}->[$i]->{bindto};
                
            $tvars->{colm} = $profile->{columns}->[$i];
            $grid_parts[$counter++] = $tempro->($self->temppath('tdata.tt'), $tvars);
            
        }
        
        push @grid_table, $tempro->($self->temppath('trow.tt'), {
            content => join( "\n", @grid_parts ),
        });
        
        @grid_parts = ();
        $counter = 0;
        
    }
    
    # navigation
    
    return $tempro->($self->temppath('table.tt'), {
        content => join( "\n", @grid_table ),
    });
}

sub render_control {
    my ( $self, @fields ) = @_;
    my $form_vars = {};

    # check for form template vars
    if ( ref( $fields[@fields] ) eq "HASH" ) {
        $form_vars = pop @fields;
    }

    my $counter    = 0;
    my @form_parts = ();
    foreach my $field (@fields) {
        $self->{data}->check_field($field);
        die "The field `$field` does not have an element directive"
          unless defined $self->{data}->{fields}->{$field}->{element};
        my $template = Template->new(
            INTERPOLATE => 1,
            EVAL_PERL   => 1,
            ABSOLUTE    => 1,
            ANYCASE     => 1
        );
        my $type = $self->{data}->{fields}->{$field}->{element}->{type};
        my $html = $self->temppath( $self->{templates}->{$type} );
        $html =
          $self->temppath(
            $self->{data}->{fields}->{$field}->{element}->{template} )
          if defined $self->{data}->{fields}->{$field}->{element}->{template};

        my $tvars = $self->{data}->{fields}->{$field};
        $tvars->{name} = $field;
        my $args = {
            form  => $self->{data},
            field => $tvars,
            this  => $field,
            vars  => $form_vars
        };
        $form_parts[$counter] = '';
        $template->process( $html, $args, \$form_parts[$counter] );
        $counter++;
    }

    return @form_parts;
}

sub templates {
    my ( $self, $path ) = @_;
    return $self->{data}->{templates}->{directory} = $path;
}

# The temppath method concatenates a file with the template directory and
# returns an absolute path
sub temppath {
    my ( $self, $file ) = @_;
    return path( $self->{templates}->{directory}, $file );
}

# The dynamic Template::Stash::LIST_OPS has method adds a 'find-in-array'
# virtual list method for Template-Toolkit
$Template::Stash::LIST_OPS->{has} = sub {
    my ( $list, $value ) = @_;
    return ( grep /$value/, @$list ) ? 1 : 0;
};

1;