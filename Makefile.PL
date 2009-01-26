use strict;
use warnings;

use inc::Module::Install;

# Define metadata
name 'CatalystX-CRUD-YUI';
all_from 'lib/CatalystX/CRUD/YUI.pm';

requires 'Test::More'                            => 0;
requires 'Path::Class'                           => 0;
requires 'Template'                              => 0;
requires 'Text::Autoformat'                      => 0;
requires 'Catalyst::View::TT'                    => 0;
requires 'Catalyst::Plugin::Static::Simple'      => 0;
requires 'Catalyst::Plugin::ConfigLoader'        => 0;
requires 'Config::General'                       => 0;
requires 'Catalyst::Action::RenderView'          => 0;
requires 'CatalystX::CRUD'                       => 0.37;
recommends 'CatalystX::CRUD::Model::RDBO'        => 0.16;
recommends 'CatalystX::CRUD::ModelAdapter::DBIC' => 0.07;
recommends 'Rose::DBx::Object::MoreHelpers'      => 0.06;
recommends 'DBIx::Class::RDBOHelpers'            => 0.08;
requires 'Rose::HTMLx::Form::Related'            => 0.13;
requires 'CatalystX::CRUD::Controller::RHTMLO'   => 0.18; 
requires 'CatalystX::CRUD::View::Excel'          => 0.06;
requires 'Scalar::Util'                          => 0;
requires 'Class::C3'                             => 0;
requires 'JSON::XS'                              => 2.23;
requires 'Template::Plugin::Handy'               => 0.002;

WriteAll;

