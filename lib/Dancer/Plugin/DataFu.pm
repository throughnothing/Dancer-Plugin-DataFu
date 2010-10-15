# ABSTRACT: Dancer HTML Form and Grid/Table engine with Input Validation
package Dancer::Plugin::DataFu;

use strict;
use warnings;
use Dancer qw/:syntax/;
use Dancer::Plugin;
use Dancer::Plugin::DataFu::Form;
use Dancer::Plugin::DataFu::Grid;

my  $settings = plugin_setting;

register 'form' => sub {
    return Dancer::Plugin::DataFu::Form->new($settings);
};

register 'grid' => sub {
    return Dancer::Plugin::DataFu::Grid->new($settings);
};

=head1 SYNOPSIS

    # form rendering and validation

    get 'login' => sub {
        return form->render('user.login', 'user.password');
    };
    
    post 'login' => sub {
        my $input = form;
        redirect '/dashboard' if $input->validate('user.login', 'user.password');
        return $input->render('user.login', 'user.password');
    };

=head1 DESCRIPTION

Dancer::Plugin::DataFu is an HTML form and table rendering engine with data
validation support. All HTML elements are rendered using TT (Template-Toolkit) 
templates, which can be copied to your application folder and altered as you see fit 
providing the ultimate in flexibility when rendering HTML and Validating User Input.
Form rending and input validation is done almost indentically to that of CPAN module
Oogly::Aagly, please examine that POD (documentation) for a more indepth look at
configuration.

=head1 CONFIGURATION

    plugins:
      DataFu:
        form:
          templates: views/datafu
          profiles: data/profiles
        grid:
          templates: views/datafu
          profiles: data/profiles
        
=head1 FORM PROFILES

    ... myapp/data/profiles/user.pl
    
    # user validation profile

    our $profile = {
        
        'login' => {
            label    => 'user login',
            required => 1,
            element  => {
                type => 'input_text'
            }
        },
        
        'password' => {
            label    => 'user password',
            required => 1,
            element  => {
                type => 'input_text'
            }
        }
        
    };
    
Profiles are where you would put all of your data input constraints and
validation rules. Form rending and input validation is done almost indentically
to that of CPAN module Oogly::Aagly, please examine that POD (documentation) for
a more indepth look at configuration. All profiles in the specified 'profiles'
directory are loaded automatically for DRY (don't repeat yourself) purposes,
allowing you to mix fields from different profiles. The field uses in rendering
and validation is stored and referenced using the profile name and field name
together seperated with a single period. i.e. The login field example above would
be referenced as ...

    form->validate('user.login');
    form->render('form', '/action', 'user.login');

=head1 GRID PROFILES

    our $profile = {
        
        'header'  => 'example table header',
        'columns' => [
            {
                header  => 'action',
                bindkey => 'id',
                element => {
                    type => 'input_checkbox'
                }
            },
            {
                header => 'col1',
            },
            {
                header => 'col2',
            },
            {
                header => 'col2',
            }
        ],
        
    };

=cut

register_plugin;

1;
