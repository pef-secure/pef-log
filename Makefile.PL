use ExtUtils::MakeMaker;
WriteMakefile(
	NAME        => "PEF::Log",
	AUTHOR      => "Pef Secure",
	VERSION     => "0.01",
	INSTALLDIRS => 'site',
	PREREQ_PM   => {
		Carp           => 0,
		Clone          => 0,
		"Data::Dumper" => 0,
		Exporter       => 0,
		PerlIO         => 0,
		POSIX          => 0,
		"Scalar::Util" => 0,
		"Time::HiRes"  => 0,
		"YAML::XS"     => 0
	},
	dist => {
		DIST_DEFAULT => 'all tardist',
		COMPRESS     => 'gzip -vf',
		SUFFIX       => '.gz',
	},
	clean     => {FILES => '*~',},
	realclean => {FILES => '*~',},
);
