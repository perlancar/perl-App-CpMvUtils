package App::CpMvUtils;

use 5.010001;
use strict;
use warnings;
use Log::ger;

use File::Basename;
use File::Spec;
use Path::Naive; # XXX only supports unix style

# AUTHORITY
# DATE
# DIST
# VERSION

sub _adjust_symlink {
    # both args must be symlinks, this is not checked again by this routine
    my ($symlink1, $symlink2) = @_;

    my $target1 = readlink $symlink1;
    if (!defined $target1) {
        log_warn "Cannot read source symlink %s, skipping adjusting", $symlink1;
        return;
    }
    my $target2 = readlink $symlink2;
    if (!defined $target2) {
        log_warn "Cannot read target symlink %s, skipping adjusting", $symlink2;
        return;
    }
    if (File::Spec->file_name_is_absolute($target1)) {
        log_trace "Skipping adjusting source symlink %s (target '%s' is absolute)", $symlink1, $target1;
        return;
    }
    if (File::Spec->file_name_is_absolute($target2)) {
        log_trace "Skipping adjusting target symlink %s (target '%s' is absolute)", $symlink2, $target2;
        return;
    }
    my $newtarget2 = Path::Naive::normalize_path(
        File::Spec->abs2rel(
            (File::Spec->rel2abs($target1, File::Basename::dirname($symlink1))),
            File::Spec->rel2abs(File::Basename::dirname($symlink2), "/"), # XXX "/" is unixism
        )
    );
    if ($target2 eq $newtarget2) {
        log_trace "Skipping adjusting target symlink %s (no change)", $symlink2, $newtarget2;
        return;
    }
    unlink $symlink2 or do {
        log_error "Cannot adjust target symlink %s (can't unlink: %s)", $symlink2, $!;
        return;
    };
    symlink($newtarget2, $symlink2) or do {
        log_error "Cannot adjust target symlink %s (can't symlink to '%s': %s)", $symlink2, $newtarget2, $!;
        return;
    };
    log_trace "Adjusted symlink %s (from target '%s' to target '%s')", $symlink2, $target2, $newtarget2;
}

sub adjust_symlinks_in_target {
    my %args = @_;

    unless (defined $args{target} && @{ $args{sources} }) {
        log_info "No target/sources, skipping adjusting symlinks";
        return;
    }

    # first case: one source, symlink, target is also symlink
    if (@{ $args{sources} } == 1 && -l $args{sources}[0]) {
        if (-d $args{target}) {
            my ($vol, $dirs, $file) = File::Spec->splitpath($args{sources}[0]);
            _adjust_symlink($args{sources}[0], File::Spec->catfile($args{target}, $file));
        } elsif (-l $args{target}) {
            _adjust_symlink($args{sources}[0], $args{target});
        } else {
            log_warn "Source (%s) is a symlink, but target (%s) is neither a directory or symlink, skipping", $args{sources}[0], $args{target};
        }
    } else {
        log_warn "Skipping for now";
    }
}

1;
# ABSTRACT: CLI utilities related to the Unix commands 'cp' and 'mv'

=for Pod::Coverage ^(.+)$

=head1 DESCRIPTION

This distribution includes the following CLI utilities related to the Unix
commands C<cp> and C<mv>:

# INSERT_EXECS_LIST

=cut
