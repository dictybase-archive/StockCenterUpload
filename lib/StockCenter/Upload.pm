
package StockCenter::Upload;

use strict;
use warnings;

use Mojo::Base 'Mojolicious::Controller';
use Data::Dump qw/pp/;
use StockCenter::Type::Strain;

#use DBCon::Uploader;
use File::Temp;

sub new_record {
    my ($self) = @_;
    $self->render( template => 'uploads' );
}

sub create {
    my ($self) = @_;
    my $db = $self->upload_db;
    my $sth
        = $db->prepare("INSERT INTO uploaded_file(name, size) VALUES(?, ?)");
    my ($upload) = @{ $self->req->uploads };
    my $filename = $upload->filename;
    $sth->execute( $filename, $upload->size );
    my $id = $db->last_insert_id( "", "", "", "" );

    my $temp_file = File::Temp->new( SUFFIX => '.dat' );
    $upload->move_to($temp_file);
    $self->app->log->info('File uploaded to /tmp');

#$upload->move_to($self->app->home->rel_file( "uploads/" . $id . "_" . $filename ) );
    my $headers = $self->res->headers;
    $headers->content_type('text/plain');

    #$headers->location( $self->url_for("uploads/$id")->to_abs );

    my $file = $temp_file->filename;

 #my $file = $self->app->home->rel_file( "uploads/" . $id . "_" . $filename );

    $self->app->log->debug('Parsing & loading');
    my $parser = StockCenter::Type::Strain->new();
    $parser->file($file);
    my $adapter = $self->adapter;
    while ( $parser->has_next() ) {
        my $row = $parser->next();
		#$self->app->log->debug( $row->count );
        for my $k ( $row->row_keys ) {
            $self->app->log->debug( $k . " -> " . $row->get_row($k) );
        }

        #$adapter->insert($row);
    }
    $self->rendered(201);
    return;

}

sub index {
}

sub search {
    my ($self) = @_;
    my $limit  = $self->param('iDisplayLength');
    my $offset = $self->param('iDisplayStart');
    my $db     = $self->upload_db;
    my $sth
        = $db->prepare(
        "SELECT name, size, created_at FROM uploaded_file LIMIT $offset,$limit"
        );
    my $cth     = $db->prepare("SELECT count(id) FROM uploaded_file");
    my ($total) = $db->selectrow_array($cth);
    my $arr     = $db->selectall_arrayref($sth);

    $self->render_json(
        {   sEcho                => $self->param('sEcho'),
            iTotalRecords        => $total,
            iTotalDisplayRecords => $total,
            aaData               => $arr
        }
    );
    return;
}

1;
