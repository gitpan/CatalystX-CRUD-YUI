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
requires 'Catalyst::Action::RenderView'          => 0;
requires 'CatalystX::CRUD'                       => 0.32;
recommends 'CatalystX::CRUD::Model::RDBO'        => 0.14;
recommends 'CatalystX::CRUD::ModelAdapter::DBIC' => 0.07;
recommends 'Rose::DBx::Object::MoreHelpers'      => 0.03;
recommends 'DBIx::Class::RDBOHelpers'            => 0.07;
requires 'Rose::HTMLx::Form::Related'            => 0.09;
requires 'CatalystX::CRUD::Controller::RHTMLO'   => 0.18; 
requires 'CatalystX::CRUD::View::Excel'          => 0.06;
requires 'Scalar::Util'                          => 0;
requires 'Class::C3'                             => 0;
requires 'JSON::XS'                              => 2.23;
requires 'Template::Plugin::Handy'               => 0;

WriteAll;

