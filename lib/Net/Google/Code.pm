package Net::Google::Code;

use Moose;
with 'Net::Google::Code::Role::Fetchable', 'Net::Google::Code::Role::URL',
  'Net::Google::Code::Role::Pageable';

our $VERSION = '0.05';

has 'project' => (
    isa      => 'Str',
    is       => 'rw',
);

has 'labels' => (
    isa => 'ArrayRef',
    is  => 'rw',
);

has 'owners' => (
    isa => 'ArrayRef',
    is  => 'rw',
);

has 'members' => (
    isa => 'ArrayRef',
    is  => 'rw',
);

has 'summary' => (
    isa => 'Str',
    is  => 'rw',
);

has 'description' => (
    isa => 'Str',
    is  => 'rw',
);

has 'issues' => (
    isa => 'ArrayRef[Net::Google::Code::Issue]',
    is  => 'rw',
);

has 'downloads' => (
    isa => 'ArrayRef[Net::Google::Code::Download]',
    is  => 'rw',
);

has 'wikis' => (
    isa => 'ArrayRef[Net::Google::Code::Wiki]',
    is  => 'rw',
);

sub load {
    my $self = shift;
    my $content = $self->fetch( $self->base_url );
    return $self->parse( $content );
}

sub parse {
    my $self    = shift;
    my $content = shift;
    require HTML::TreeBuilder;
    my $tree = HTML::TreeBuilder->new;
    $tree->parse_content($content);
    $tree->elementify;

    my $summary =
      $tree->look_down( id => 'psum' )->find_by_tag_name('a')->content_array_ref->[0];
    $self->summary($summary) if $summary;

    my $description =
      $tree->look_down( id => 'wikicontent' )->content_array_ref->[0]->as_text;
    $self->description($description) if $description;

    my @members;
    my @members_tags =
      $tree->look_down( id => 'members' )->find_by_tag_name('a');
    for my $tag (@members_tags) {
        push @members, $tag->content_array_ref->[0];
    }
    $self->members( \@members ) if @members;

    my @owners;
    my @owners_tags = $tree->look_down( id => 'owners' )->find_by_tag_name('a');
    for my $tag (@owners_tags) {
        push @owners, $tag->content_array_ref->[0];
    }
    $self->owners( \@owners ) if @owners;

    my @labels;
    my @labels_tags = $tree->look_down( href => qr/q\=label\:/ );
    for my $tag (@labels_tags) {
        push @labels, $tag->content_array_ref->[0];
    }
    $self->labels( \@labels ) if @labels;

}

sub download {
    my $self = shift;
    require Net::Google::Code::Download;
    return Net::Google::Code::Download->new(
        project => $self->project,
        @_
    );
}

sub issue {
    my $self = shift;
    require Net::Google::Code::Issue;
    return Net::Google::Code::Issue->new(
        project => $self->project,
        @_
    );
}


sub load_downloads {
    my $self = shift;
    my $content = $self->fetch( $self->base_feeds_url . 'downloads/list' );
    my @names = $self->first_columns( $content );
    my @downloads;
    require Net::Google::Code::Download;
    for my $name ( @names ) {
        my $download = Net::Google::Code::Download->new(
            project => $self->project,
            name    => $name,
        );
        $download->load;
        push @downloads, $download;
    }
    $self->downloads( \@downloads );
}


sub wiki {

    my $self = shift;
    require Net::Google::Code::Wiki;
    return Net::Google::Code::Wiki->new(
        project => $self->project,
        @_
    );
}

sub load_wikis {
	my $self = shift;
	
	my $wiki_svn = $self->base_svn_url . 'wiki/';
	my $content = $self->fetch( $wiki_svn );

    require HTML::TreeBuilder;
    my $tree = HTML::TreeBuilder->new;
    $tree->parse_content($content);
    $tree->elementify;
	
    my @wikis;
    my @li = $tree->find_by_tag_name('li');
    for my $li ( @li ) {
        my $name = $li->as_text;
        if ( $name =~ /(\S+)\.wiki$/ ) {
            $name = $1;
            require Net::Google::Code::Wiki;
            my $wiki = Net::Google::Code::Wiki->new(
                project => $self->project,
                name    => $name,
            );
            $wiki->load;
            push @wikis, $wiki;
        }
    }
    $self->wikis( \@wikis );
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 NAME

Net::Google::Code - a simple client library for google code

=head1 SYNOPSIS

    use Net::Google::Code;
    
    my $project = Net::Google::Code->new( project => 'net-google-code' );
    $project->load; # load its metadata, e.g. summary, owners, members, etc.
    
    print join(', ', @{ $project->owners } );

    # return a Net::Google::Code::Issue object, of which the id is 30
    $project->issue( id => 30 ); 

    # return a Net::Google::Code::Download object, of which the file name is
    # 'FooBar-0.01.tar.gz'
    $project->download( name => 'FooBar-0.01.tar.gz' );

    # return a Net::Google::Code::Wiki object, of which the page name is 'Test'
    $project->wiki( name => 'Test' );

    # loads all the downloads
    $project->load_downloads;
    my $downloads = $project->downloads;

    # loads all the wikis
    $project->load_wikis;
    my $wikis = $project->wikis;

=head1 DESCRIPTION

Net::Google::Code is a simple client library for projects hosted in Google Code.

Currently, it focuses on the basic read functionality for that is provided.

=head1 INTERFACE

=over 4

=item load

load project's home page, and parse its metadata

=item parse

acturally do the parse job, for load();

=item load_downloads

load all the downloads, and store them as an arrayref in $self->downloads

=item load_wikis

load all the wikis, and store them as an arrayref in $self->wikis

=item project

the project name

=item base_url

the project homepage

=item base_svn_url

the project svn url (without trunk)

=item base_feeds_url

the project feeds url

=item summary

=item description

=item labels

=item owners

=item members

=item issue

return a new L<Net::Google::Code::Issue> object, arguments will be passed to
L<Net::Google::Code::Issue>'s new method.

=item download

return a new L<Net::Google::Code::Download> object, arguments will be passed to
L<Net::Google::Code::Download>'s new method.

=item wiki

return a new L<Net::Google::Code::Wiki> object, arguments will be passed to
L<Net::Google::Code::Wiki>'s new method.

=back

=head1 DEPENDENCIES

L<Moose>, L<HTML::TreeBuilder>, L<WWW::Mechanize>, L<Params::Validate>

=head1 INCOMPATIBILITIES

None reported.

=head1 BUGS AND LIMITATIONS

No bugs have been reported.

This project is very very young, and api is not stable yet, so don't use this in
production, at least for now.

=head1 AUTHOR

sunnavy  C<< <sunnavy@bestpractical.com> >>

Fayland Lam  C<< <fayland@gmail.com> >>

=head1 LICENCE AND COPYRIGHT

Copyright 2008-2009 Best Practical Solutions.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.
