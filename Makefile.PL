use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'CatalystX::CRUD::YUI',
    AUTHOR              => 'Peter Karman <karman@cpan.org>',
    VERSION_FROM        => 'lib/CatalystX/CRUD/YUI.pm',
    ABSTRACT_FROM       => 'lib/CatalystX/CRUD/YUI.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
        'Path::Class'       => 0,
        'Template'          => 0,
        'Text::Autoformat'   => 0,
        'Catalyst::View::TT' => 0,
        'CatalystX::CRUD'                     => 0.29,
        #'CatalystX::CRUD::Model::RDBO'        => 0.13, # not required
        'Rose::HTMLx::Form::Related'          => 0.03,
        'CatalystX::CRUD::Controller::RHTMLO' => 0.16,
        'CatalystX::CRUD::View::Excel'        => 0.05,
        'Scalar::Util'     => 0,
        'Class::C3'        => 0,

    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'CatalystX-CRUD-YUI-*' },
);
